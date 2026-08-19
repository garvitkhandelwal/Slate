import Foundation
import UIKit
@testable import Slate

/// Records operations, never task text, and can fail the next call with an injected error.
@MainActor
final class FakePlannerRepository: PlannerRepository {
    enum Call: String, Equatable { case fetchWeek, add, update, toggle, delete, deleteBefore }

    private(set) var calls: [Call] = []
    var tasks: [TaskSnapshot] = []
    var nextError: PlannerError?
    var deleteBeforeCutoffs: [LocalDay] = []

    init(tasks: [TaskSnapshot] = [], nextError: PlannerError? = nil) {
        self.tasks = tasks
        self.nextError = nextError
    }

    var callNames: [String] { calls.map(\.rawValue) }

    private func failIfNeeded() throws {
        if let error = nextError {
            nextError = nil
            throw error
        }
    }

    func fetchTasks(in week: WeekInterval) throws -> [TaskSnapshot] {
        calls.append(.fetchWeek)
        try failIfNeeded()
        return tasks
            .filter { week.days.contains($0.day) }
            .sorted { ($0.day, $0.createdAt, $0.id.uuidString) < ($1.day, $1.createdAt, $1.id.uuidString) }
    }

    func addTask(text: String, on day: LocalDay, createdAt: Date) throws -> TaskSnapshot {
        calls.append(.add)
        try failIfNeeded()
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw PlannerError.persistence(operation: .add) }
        let snapshot = TaskSnapshot(id: UUID(), text: value, day: day, isCompleted: false, createdAt: createdAt)
        tasks.append(snapshot)
        return snapshot
    }

    func updateTask(id: UUID, text: String) throws -> TaskSnapshot {
        calls.append(.update)
        try failIfNeeded()
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let index = tasks.firstIndex(where: { $0.id == id }) else {
            throw PlannerError.persistence(operation: .update)
        }
        let old = tasks[index]
        let updated = TaskSnapshot(id: old.id, text: value, day: old.day, isCompleted: old.isCompleted, createdAt: old.createdAt)
        tasks[index] = updated
        return updated
    }

    func toggleCompletion(id: UUID) throws -> TaskSnapshot {
        calls.append(.toggle)
        try failIfNeeded()
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { throw PlannerError.persistence(operation: .toggle) }
        let old = tasks[index]
        let updated = TaskSnapshot(id: old.id, text: old.text, day: old.day, isCompleted: !old.isCompleted, createdAt: old.createdAt)
        tasks[index] = updated
        return updated
    }

    func deleteTask(id: UUID) throws {
        calls.append(.delete)
        try failIfNeeded()
        guard tasks.contains(where: { $0.id == id }) else { throw PlannerError.persistence(operation: .delete) }
        tasks.removeAll { $0.id == id }
    }

    func deleteTasks(before cutoff: LocalDay) throws -> Int {
        calls.append(.deleteBefore)
        deleteBeforeCutoffs.append(cutoff)
        try failIfNeeded()
        let before = tasks.count
        tasks.removeAll { $0.day < cutoff }
        return before - tasks.count
    }
}

/// Starts at a fixed instant and advances one millisecond per read, like a real monotonic clock,
/// so creation timestamps stay distinct within a test while never crossing a day boundary.
final class FakeDateProvider: DateProviding, @unchecked Sendable {
    let start: Date
    private let lock = NSLock()
    private var ticks = 0

    init(date: Date) {
        start = date
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        ticks += 1
        return start.addingTimeInterval(Double(ticks) * 0.001)
    }
}

actor FakeWallpaperStore: WallpaperStoring {
    enum Call: Equatable { case load, save(Int), remove(Int) }

    private(set) var stored: [Data]
    private(set) var calls: [Call] = []
    var loadError: PlannerError?
    var saveError: PlannerError?
    var removeError: PlannerError?

    init(stored: [Data] = []) {
        self.stored = stored
    }

    func setStored(_ data: [Data]) { stored = data }
    func setLoadError(_ error: PlannerError?) { loadError = error }
    func setSaveError(_ error: PlannerError?) { saveError = error }
    func setRemoveError(_ error: PlannerError?) { removeError = error }

    func loadAll() async throws -> [Data] {
        calls.append(.load)
        if let loadError { throw loadError }
        return stored
    }

    func saveImportedImage(_ data: Data, slot: Int) async throws {
        calls.append(.save(slot))
        if let saveError { throw saveError }
        if stored.indices.contains(slot) {
            stored[slot] = data
        } else if slot == stored.count, slot < WallpaperSlots.count {
            stored.append(data)
        } else {
            throw PlannerError.wallpaperStorage
        }
    }

    func remove(slot: Int) async throws {
        calls.append(.remove(slot))
        if let removeError { throw removeError }
        guard stored.indices.contains(slot) else { return }
        stored.remove(at: slot)
    }
}

@MainActor
final class FakeHaptics: HapticClient {
    enum Event: Equatable { case light, medium }
    private(set) var events: [Event] = []
    func light() { events.append(.light) }
    func medium() { events.append(.medium) }
}

/// Constructs every dependency around a `PlannerViewModel` and exposes them to each test.
@MainActor
struct PlannerHarness {
    let repository: FakePlannerRepository
    let wallpaperStore: FakeWallpaperStore
    let haptics: FakeHaptics
    let defaults: UserDefaults
    let calendarService: CalendarService
    let dateProvider: FakeDateProvider
    let model: PlannerViewModel

    init(
        now: Date = TestFixtures.august19,
        tasks: [TaskSnapshot] = [],
        repositoryError: PlannerError? = nil,
        wallpaperData: Data? = nil,
        wallpapers: [Data] = [],
        selectedWallpaperIndex: Int? = nil,
        calendarService: CalendarService = TestFixtures.gregorianCalendarService()
    ) {
        repository = FakePlannerRepository(tasks: tasks, nextError: repositoryError)
        wallpaperStore = FakeWallpaperStore(stored: wallpaperData.map { [$0] } ?? wallpapers)
        haptics = FakeHaptics()
        defaults = TestFixtures.isolatedDefaults("PlannerHarness")
        if let selectedWallpaperIndex {
            defaults.set(selectedWallpaperIndex, forKey: PlannerViewModel.selectedWallpaperKey)
        } else if wallpaperData != nil {
            // A single seeded wallpaper is showing, matching the pre-slot behaviour the tests were written for.
            defaults.set(0, forKey: PlannerViewModel.selectedWallpaperKey)
        }
        self.calendarService = calendarService
        dateProvider = FakeDateProvider(date: now)
        let environment = AppEnvironment(
            repository: repository,
            wallpaperStore: wallpaperStore,
            retentionService: RetentionService(repository: repository, calendarService: calendarService, defaults: defaults),
            haptics: haptics,
            dateProvider: dateProvider,
            calendarService: calendarService,
            defaults: defaults
        )
        model = PlannerViewModel(environment: environment)
    }
}
