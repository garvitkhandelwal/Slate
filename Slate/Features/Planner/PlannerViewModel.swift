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
    var isPhotoPickerPresented = false
    /// Decoded stored wallpapers in slot order (at most `WallpaperSlots.count`).
    private(set) var wallpapers: [UIImage] = []
    /// Which stored wallpaper is showing; `nil` shows the flat ground.
    private(set) var selectedWallpaperIndex: Int?
    /// Persisted in-app appearance; `nil` follows the system.
    private(set) var appearanceOverride: ColorScheme?
    var presentedError: PlannerError?

    nonisolated static let selectedWallpaperKey = "selectedWallpaperIndex"
    nonisolated static let appearanceOverrideKey = "appearanceOverride"

    init(environment: AppEnvironment) {
        self.environment = environment
        let today = LocalDay(date: environment.dateProvider.now(), calendar: environment.calendarService.calendar)
        displayedWeek = environment.calendarService.week(containing: today)
        for day in displayedWeek.days { tasksByDay[day] = [] }
        selectedWallpaperIndex = environment.defaults.object(forKey: Self.selectedWallpaperKey) as? Int
        switch environment.defaults.string(forKey: Self.appearanceOverrideKey) {
        case "light": appearanceOverride = .light
        case "dark": appearanceOverride = .dark
        default: appearanceOverride = nil
        }
    }

    /// The wallpaper currently rendered behind week and day content.
    var wallpaperImage: UIImage? {
        guard let index = selectedWallpaperIndex, wallpapers.indices.contains(index) else { return nil }
        return wallpapers[index]
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

    /// Visible label of the wallpaper switch: `PHOTO` when nothing is showing, else `n/N`.
    var wallpaperSwitchLabel: String {
        guard let index = selectedWallpaperIndex, wallpapers.indices.contains(index) else {
            return AccessibilityLabels.photo
        }
        return "\(index + 1)/\(wallpapers.count)"
    }

    /// Steps 1/N → … → N/N → none → 1/N. With nothing stored it opens the photo picker instead.
    func cycleWallpaper() {
        guard resolveCurrentCapture() else { return }
        guard !wallpapers.isEmpty else {
            isPhotoPickerPresented = true
            return
        }
        let next: Int?
        switch selectedWallpaperIndex {
        case .none: next = 0
        case let .some(index) where index + 1 < wallpapers.count: next = index + 1
        default: next = nil
        }
        select(wallpaperIndex: next)
    }

    /// Loads the selection through the picker bridge, persists the processed copy, then reloads and decodes
    /// the sandboxed files so visible state always represents persisted data.
    func importWallpaper(_ item: PhotosPickerItem) async {
        do {
            let data = try await WallpaperPickerBridge().data(from: item)
            await importWallpaper(data: data)
        } catch {
            presentedError = error as? PlannerError ?? .wallpaperImport
        }
    }

    /// Fills the next free slot, or replaces the showing wallpaper (else the last one) when all slots are full.
    func importWallpaper(data: Data) async {
        let slot: Int
        if wallpapers.count < WallpaperSlots.count {
            slot = wallpapers.count
        } else {
            slot = selectedWallpaperIndex ?? (wallpapers.count - 1)
        }
        do {
            try await environment.wallpaperStore.saveImportedImage(data, slot: slot)
            await loadWallpapers()
            select(wallpaperIndex: wallpapers.indices.contains(slot) ? slot : nil)
        } catch {
            presentedError = error as? PlannerError ?? .wallpaperImport
        }
    }

    /// Deletes the showing wallpaper first; visible state clears only after the removal succeeds.
    func removeWallpaper() async {
        guard let index = selectedWallpaperIndex, wallpapers.indices.contains(index) else { return }
        do {
            try await environment.wallpaperStore.remove(slot: index)
            await loadWallpapers()
            select(wallpaperIndex: nil)
        } catch {
            presentedError = error as? PlannerError ?? .wallpaperStorage
        }
    }

    private func select(wallpaperIndex index: Int?) {
        selectedWallpaperIndex = index
        if let index {
            environment.defaults.set(index, forKey: Self.selectedWallpaperKey)
        } else {
            environment.defaults.removeObject(forKey: Self.selectedWallpaperKey)
        }
    }

    /// Decodes every stored wallpaper off the main actor. A corrupt or unreadable slot falls back to no
    /// wallpaper for that slot and is removed silently; the showing index is clamped to what remains.
    private func loadWallpapers() async {
        var decoded: [UIImage] = []
        do {
            let stored = try await environment.wallpaperStore.loadAll()
            var corruptSlots: [Int] = []
            for (slot, data) in stored.enumerated() {
                if let image = try? await WallpaperImageLoader().image(from: data) {
                    decoded.append(image)
                } else {
                    corruptSlots.append(slot)
                }
            }
            // Remove from the highest slot down so compaction never shifts a slot still pending removal.
            for slot in corruptSlots.reversed() {
                try? await environment.wallpaperStore.remove(slot: slot)
            }
        } catch {
            decoded = []
        }
        wallpapers = decoded
        if let index = selectedWallpaperIndex, !decoded.indices.contains(index) {
            select(wallpaperIndex: decoded.isEmpty ? nil : decoded.count - 1)
        }
    }

    /// Kept for the launch path: `start()` loads wallpapers after the first fetch.
    private func loadWallpaper() async {
        await loadWallpapers()
    }

    // MARK: Appearance

    /// The label names the appearance a tap switches to.
    func appearanceSwitchLabel(current: ColorScheme) -> String {
        current == .dark ? AccessibilityLabels.light : AccessibilityLabels.dark
    }

    /// Flips from the effective appearance and persists the choice; the first tap leaves "system" behind.
    func toggleAppearance(current: ColorScheme) {
        let next: ColorScheme = current == .dark ? .light : .dark
        appearanceOverride = next
        environment.defaults.set(next == .dark ? "dark" : "light", forKey: Self.appearanceOverrideKey)
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
