import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// The single owner of mutable UI state shared by the weekly and daily surfaces.
/// Every mutation routes through the repository; state changes only after persistence succeeds.
@MainActor
@Observable
final class PlannerViewModel {
    private let environment: AppEnvironment

    private(set) var displayedWeek: WeekInterval
    private(set) var tasksByDay: [LocalDay: [TaskSnapshot]] = [:]
    var route: [RootRoute] = []
    var capture: CaptureSession = .none
    var isWeekPickerExpanded = false
    var isWallpaperDialogPresented = false
    private(set) var wallpaperImage: UIImage?
    var presentedError: PlannerError?

    init(environment: AppEnvironment) {
        self.environment = environment
        let today = LocalDay(date: environment.dateProvider.now(), calendar: environment.calendarService.calendar)
        displayedWeek = environment.calendarService.week(containing: today)
        for day in displayedWeek.days { tasksByDay[day] = [] }
    }

    // MARK: Derived facts for views

    var calendarService: CalendarService { environment.calendarService }

    var today: LocalDay {
        LocalDay(date: environment.dateProvider.now(), calendar: environment.calendarService.calendar)
    }

    func isToday(_ day: LocalDay) -> Bool {
        environment.calendarService.isToday(day, now: environment.dateProvider.now())
    }

    var currentWeek: WeekInterval { environment.calendarService.week(containing: today) }

    var pickerWeeks: [WeekInterval] { environment.calendarService.pickerWeeks(centeredOn: displayedWeek) }

    func tasks(on day: LocalDay) -> [TaskSnapshot] { tasksByDay[day, default: []] }

    // MARK: Lifecycle

    /// Foreground retention runs synchronously before the first fetch; wallpaper loads in a child task
    /// so a slow image never blocks task interaction.
    func start() async {
        try? environment.retentionService.purgeExpiredTasks(now: environment.dateProvider.now())
        reloadDisplayedWeek()
        async let wallpaper: Void = loadWallpaper()
        _ = await wallpaper
    }

    func reloadDisplayedWeek() {
        do {
            let tasks = try environment.repository.fetchTasks(in: displayedWeek)
            var grouped = Dictionary(grouping: tasks, by: \.day)
            for day in displayedWeek.days where grouped[day] == nil { grouped[day] = [] }
            tasksByDay = grouped
        } catch {
            presentedError = error as? PlannerError ?? .persistence(operation: .fetch)
        }
    }

    /// Recomputes the displayed week through the current calendar so locale or first-weekday changes
    /// made while inactive take effect, then refreshes its data.
    func handleSceneActivation() {
        displayedWeek = environment.calendarService.week(containing: displayedWeek.days[3])
        reloadDisplayedWeek()
    }

    // MARK: Week navigation

    func showPreviousWeek() {
        display(environment.calendarService.adjacentWeek(from: displayedWeek, offset: -1))
    }

    func showNextWeek() {
        display(environment.calendarService.adjacentWeek(from: displayedWeek, offset: 1))
    }

    func selectWeek(containing day: LocalDay) {
        isWeekPickerExpanded = false
        display(environment.calendarService.week(containing: day))
    }

    private func display(_ week: WeekInterval) {
        guard resolveCurrentCapture() else { return }
        displayedWeek = week
        reloadDisplayedWeek()
    }

    // MARK: Routing

    func openDay(_ day: LocalDay) {
        guard resolveCurrentCapture() else { return }
        isWeekPickerExpanded = false
        route.append(.day(day))
    }

    // MARK: Capture

    func beginAdding(on day: LocalDay) {
        if capture == .adding(day: day, draft: "") { return }
        guard resolveCurrentCapture() else { return }
        capture = .adding(day: day, draft: "")
    }

    func beginEditing(_ task: TaskSnapshot) {
        if capture.isEditing(task.id) { return }
        guard resolveCurrentCapture() else { return }
        capture = .editing(task: task, draft: task.text)
    }

    func updateDraft(_ text: String) {
        switch capture {
        case .none:
            break
        case let .adding(day, _):
            capture = .adding(day: day, draft: text)
        case let .editing(task, _):
            capture = .editing(task: task, draft: text)
        }
    }

    /// Trims once. A nonempty add persists and, when `keepAdding`, keeps an empty session focused for rapid entry.
    /// A nonempty edit replaces the stored text; an empty edit cancels and keeps the original. Failures retain
    /// the field and the exact draft so the user can retry.
    func submitCapture(keepAdding: Bool) {
        switch capture {
        case .none:
            return
        case let .adding(day, draft):
            let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                capture = .none
                return
            }
            do {
                let snapshot = try environment.repository.addTask(text: value, on: day, createdAt: environment.dateProvider.now())
                insertTask(snapshot)
                capture = keepAdding ? .adding(day: day, draft: "") : .none
            } catch {
                presentedError = error as? PlannerError ?? .persistence(operation: .add)
            }
        case let .editing(task, draft):
            let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value != task.text else {
                capture = .none
                return
            }
            do {
                replaceTask(try environment.repository.updateTask(id: task.id, text: value))
                capture = .none
            } catch {
                presentedError = error as? PlannerError ?? .persistence(operation: .update)
            }
        }
    }

    /// Outside taps and navigation commit any valid draft first; discarding drops the draft silently.
    func dismissCapture(committing: Bool) {
        if committing {
            submitCapture(keepAdding: false)
        } else {
            capture = .none
        }
    }

    // MARK: Task mutations

    func toggleTask(_ id: UUID) {
        do {
            replaceTask(try environment.repository.toggleCompletion(id: id))
            environment.haptics.light()
        } catch {
            presentedError = error as? PlannerError ?? .persistence(operation: .toggle)
        }
    }

    func deleteTask(_ id: UUID) {
        do {
            try environment.repository.deleteTask(id: id)
            removeTask(id)
            if capture.isEditing(id) { capture = .none }
            environment.haptics.medium()
        } catch {
            presentedError = error as? PlannerError ?? .persistence(operation: .delete)
        }
    }

    // MARK: Wallpaper

    /// Loads the selection through the picker bridge, persists the processed copy, then reloads and decodes
    /// the sandboxed file so visible state always represents persisted data.
    func importWallpaper(_ item: PhotosPickerItem) async {
        do {
            let data = try await WallpaperPickerBridge().data(from: item)
            await importWallpaper(data: data)
        } catch {
            presentedError = error as? PlannerError ?? .wallpaperImport
        }
    }

    func importWallpaper(data: Data) async {
        do {
            try await environment.wallpaperStore.saveImportedImage(data)
            await loadWallpaper()
        } catch {
            presentedError = error as? PlannerError ?? .wallpaperImport
        }
    }

    /// Deletes the sandboxed file first; visible state clears only after the removal succeeds.
    func removeWallpaper() async {
        do {
            try await environment.wallpaperStore.remove()
            wallpaperImage = nil
        } catch {
            presentedError = error as? PlannerError ?? .wallpaperStorage
        }
    }

    private func loadWallpaper() async {
        do {
            guard let data = try await environment.wallpaperStore.load() else {
                wallpaperImage = nil
                return
            }
            wallpaperImage = try await WallpaperImageLoader().image(from: data)
        } catch {
            // A corrupt or unreadable stored file falls back to no wallpaper and is removed silently.
            wallpaperImage = nil
            try? await environment.wallpaperStore.remove()
        }
    }

    // MARK: Private state helpers

    /// Commits a valid current draft, drops an empty add draft, and cancels an empty edit draft.
    /// Returns `false` when a commit failed so the caller leaves the retryable session in place.
    @discardableResult
    private func resolveCurrentCapture() -> Bool {
        guard capture.isActive else { return true }
        submitCapture(keepAdding: false)
        return capture == .none
    }

    private func insertTask(_ snapshot: TaskSnapshot) {
        var tasks = tasksByDay[snapshot.day, default: []]
        tasks.removeAll { $0.id == snapshot.id }
        tasks.append(snapshot)
        tasks.sort { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        tasksByDay[snapshot.day] = tasks
    }

    private func replaceTask(_ snapshot: TaskSnapshot) {
        guard var tasks = tasksByDay[snapshot.day], let index = tasks.firstIndex(where: { $0.id == snapshot.id }) else {
            insertTask(snapshot)
            return
        }
        tasks[index] = snapshot
        tasksByDay[snapshot.day] = tasks
    }

    private func removeTask(_ id: UUID) {
        for (day, tasks) in tasksByDay where tasks.contains(where: { $0.id == id }) {
            tasksByDay[day] = tasks.filter { $0.id != id }
        }
    }
}
