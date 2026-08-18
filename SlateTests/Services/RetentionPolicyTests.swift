import SwiftData
import XCTest
@testable import Slate

final class RetentionPolicyTests: XCTestCase {
    func testJulyEighteenthCutoffIsJuneEighteenth() {
        let service = TestFixtures.gregorianCalendarService()
        XCTAssertEqual(
            RetentionPolicy().cutoff(today: .init(year: 2026, month: 7, day: 18), calendarService: service),
            .init(year: 2026, month: 6, day: 18)
        )
    }

    func testLeapAndDSTBoundariesUseCalendarDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let service = CalendarService(calendar: calendar, locale: Locale(identifier: "en_US"))
        // 2024 is a leap year and the US DST transition (10 March 2024) sits inside the window.
        XCTAssertEqual(
            RetentionPolicy().cutoff(today: .init(year: 2024, month: 3, day: 20), calendarService: service),
            .init(year: 2024, month: 2, day: 19)
        )
        // Autumn transition (3 November 2024) inside the window.
        XCTAssertEqual(
            RetentionPolicy().cutoff(today: .init(year: 2024, month: 11, day: 20), calendarService: service),
            .init(year: 2024, month: 10, day: 21)
        )
    }

    func testCutoffCrossesYearBoundary() {
        let service = TestFixtures.gregorianCalendarService()
        XCTAssertEqual(
            RetentionPolicy().cutoff(today: .init(year: 2026, month: 1, day: 10), calendarService: service),
            .init(year: 2025, month: 12, day: 11)
        )
    }
}

@MainActor
final class RetentionServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataPlannerRepository!
    private var defaults: UserDefaults!
    private var service: RetentionService!
    private let calendarService = TestFixtures.gregorianCalendarService()

    override func setUpWithError() throws {
        container = try ModelContainerFactory.inMemory()
        repository = SwiftDataPlannerRepository(container: container)
        defaults = TestFixtures.isolatedDefaults()
        service = RetentionService(repository: repository, calendarService: calendarService, defaults: defaults)
    }

    private func seedJuneBoundaryTasks() throws {
        _ = try repository.addTask(text: "june 17", on: .init(year: 2026, month: 6, day: 17), createdAt: .distantPast)
        _ = try repository.addTask(text: "june 18", on: .init(year: 2026, month: 6, day: 18), createdAt: .distantPast)
        _ = try repository.addTask(text: "future", on: .init(year: 2026, month: 12, day: 25), createdAt: .distantPast)
    }

    func testPurgeOnJulyEighteenthDeletesJuneSeventeenthAndKeepsJuneEighteenth() throws {
        try seedJuneBoundaryTasks()
        XCTAssertEqual(try service.purgeExpiredTasks(now: TestFixtures.july18), 1)
        let june = calendarService.week(containing: .init(year: 2026, month: 6, day: 18))
        XCTAssertEqual(try repository.fetchTasks(in: june).map(\.text), ["june 18"])
        let december = calendarService.week(containing: .init(year: 2026, month: 12, day: 25))
        XCTAssertEqual(try repository.fetchTasks(in: december).map(\.text), ["future"])
    }

    func testColdStartPurgeRecordsDaySoActivationDoesNotRepeat() throws {
        try seedJuneBoundaryTasks()
        XCTAssertEqual(try service.purgeExpiredTasks(now: TestFixtures.july18), 1)
        XCTAssertEqual(defaults.string(forKey: RetentionService.successfulDayKey), "2026-07-18")
        _ = try repository.addTask(text: "expired later", on: .init(year: 2026, month: 5, day: 1), createdAt: .distantPast)
        XCTAssertEqual(try service.purgeIfNeeded(now: TestFixtures.july18), 0, "Same-day activation performs no duplicate delete")
    }

    func testNextDayPurgeRunsAgain() throws {
        try seedJuneBoundaryTasks()
        _ = try service.purgeIfNeeded(now: TestFixtures.july18)
        let july19 = TestFixtures.july18.addingTimeInterval(24 * 60 * 60)
        XCTAssertEqual(try service.purgeIfNeeded(now: july19), 1, "June 18 expires on July 19")
        XCTAssertEqual(defaults.string(forKey: RetentionService.successfulDayKey), "2026-07-19")
    }

    func testFailedPurgeLeavesSavedDayUntouchedAndRetries() throws {
        struct Boom: Error {}
        let failing = SwiftDataPlannerRepository(container: container, save: { throw Boom() })
        let failingService = RetentionService(repository: failing, calendarService: calendarService, defaults: defaults)
        try seedJuneBoundaryTasks()
        XCTAssertThrowsError(try failingService.purgeIfNeeded(now: TestFixtures.july18))
        XCTAssertNil(defaults.string(forKey: RetentionService.successfulDayKey))
        XCTAssertEqual(try service.purgeIfNeeded(now: TestFixtures.july18), 1, "Remains eligible on the next activation")
    }
}

@MainActor
final class AppLifecycleCoordinatorTests: XCTestCase {
    private final class FakeRefreshTask: BackgroundRefreshTask {
        var expirationHandler: (() -> Void)?
        var completions: [Bool] = []
        func setTaskCompleted(success: Bool) { completions.append(success) }
    }

    private final class SchedulerRecorder {
        var registeredIdentifiers: [String] = []
        var launchHandler: (@MainActor @Sendable (any BackgroundRefreshTask) -> Void)?
        var submissions: [(identifier: String, earliest: Date)] = []
        var submitError: Error?
    }

    private var container: ModelContainer!
    private var repository: SwiftDataPlannerRepository!
    private var defaults: UserDefaults!
    private var recorder: SchedulerRecorder!
    private var coordinator: AppLifecycleCoordinator!
    private let calendarService = TestFixtures.gregorianCalendarService()

    private struct FixedClock: DateProviding {
        let date: Date
        func now() -> Date { date }
    }

    override func setUpWithError() throws {
        container = try ModelContainerFactory.inMemory()
        repository = SwiftDataPlannerRepository(container: container)
        defaults = TestFixtures.isolatedDefaults()
        recorder = SchedulerRecorder()
        coordinator = makeCoordinator(now: TestFixtures.july18)
    }

    private func makeCoordinator(now: Date) -> AppLifecycleCoordinator {
        let recorder = recorder!
        let scheduling = AppLifecycleCoordinator.BackgroundScheduling(
            register: { identifier, handler in
                recorder.registeredIdentifiers.append(identifier)
                recorder.launchHandler = handler
                return true
            },
            submit: { identifier, earliest in
                if let error = recorder.submitError { throw error }
                recorder.submissions.append((identifier, earliest))
            }
        )
        return AppLifecycleCoordinator(
            retentionService: RetentionService(repository: repository, calendarService: calendarService, defaults: defaults),
            dateProvider: FixedClock(date: now),
            calendarService: calendarService,
            scheduling: scheduling,
            backgroundIdentifier: "com.garvit.Slate.retention"
        )
    }

    func testRegistersOnceWithBundleDerivedIdentifier() {
        coordinator.registerBackgroundTask()
        coordinator.registerBackgroundTask()
        XCTAssertEqual(recorder.registeredIdentifiers, ["com.garvit.Slate.retention"])
        XCTAssertEqual(coordinator.backgroundIdentifier, "com.garvit.Slate.retention")
    }

    func testBecameActivePurgesOncePerDayAndSchedulesRefresh() throws {
        _ = try repository.addTask(text: "expired", on: .init(year: 2026, month: 6, day: 17), createdAt: .distantPast)
        coordinator.handleBecameActive()
        XCTAssertEqual(defaults.string(forKey: RetentionService.successfulDayKey), "2026-07-18")
        XCTAssertEqual(recorder.submissions.count, 1)
        XCTAssertEqual(recorder.submissions.first?.identifier, "com.garvit.Slate.retention")
        XCTAssertEqual(recorder.submissions.first?.earliest, TestFixtures.july18.addingTimeInterval(24 * 60 * 60))

        _ = try repository.addTask(text: "expired 2", on: .init(year: 2026, month: 6, day: 1), createdAt: .distantPast)
        coordinator.handleBecameActive()
        let june = calendarService.week(containing: .init(year: 2026, month: 6, day: 1))
        XCTAssertEqual(try repository.fetchTasks(in: june).count, 1, "Same-day activation does not purge again")
    }

    func testFailedSubmissionIsSwallowed() {
        struct Boom: Error {}
        recorder.submitError = Boom()
        coordinator.handleBecameActive()
        XCTAssertTrue(recorder.submissions.isEmpty)
    }

    func testBackgroundLaunchPurgesReschedulesAndCompletes() async throws {
        _ = try repository.addTask(text: "expired", on: .init(year: 2026, month: 6, day: 17), createdAt: .distantPast)
        coordinator.registerBackgroundTask()
        let task = FakeRefreshTask()
        recorder.launchHandler?(task)
        XCTAssertNotNil(task.expirationHandler)
        XCTAssertEqual(recorder.submissions.count, 1, "Next refresh is scheduled before work runs")

        // The purge runs in a main-actor task; yield until it reports completion.
        for _ in 0..<50 where task.completions.isEmpty { await Task.yield() }
        XCTAssertEqual(task.completions, [true])
        XCTAssertEqual(defaults.string(forKey: RetentionService.successfulDayKey), "2026-07-18")
    }

    func testBackgroundLaunchFailureCompletesWithoutSuccess() async throws {
        struct Boom: Error {}
        let failing = SwiftDataPlannerRepository(container: container, save: { throw Boom() })
        let recorder = recorder!
        let scheduling = AppLifecycleCoordinator.BackgroundScheduling(
            register: { _, handler in recorder.launchHandler = handler; return true },
            submit: { _, _ in }
        )
        let coordinator = AppLifecycleCoordinator(
            retentionService: RetentionService(repository: failing, calendarService: calendarService, defaults: defaults),
            dateProvider: FixedClock(date: TestFixtures.july18),
            calendarService: calendarService,
            scheduling: scheduling,
            backgroundIdentifier: "com.garvit.Slate.retention"
        )
        _ = try repository.addTask(text: "expired", on: .init(year: 2026, month: 6, day: 17), createdAt: .distantPast)
        coordinator.registerBackgroundTask()
        let task = FakeRefreshTask()
        recorder.launchHandler?(task)
        for _ in 0..<50 where task.completions.isEmpty { await Task.yield() }
        XCTAssertEqual(task.completions, [false])
        XCTAssertNil(defaults.string(forKey: RetentionService.successfulDayKey))
    }
}
