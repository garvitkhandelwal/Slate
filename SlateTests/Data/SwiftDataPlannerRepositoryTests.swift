import SwiftData
import XCTest
@testable import Slate

@MainActor
final class SwiftDataPlannerRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataPlannerRepository!

    override func setUpWithError() throws {
        container = try ModelContainerFactory.inMemory()
        repository = SwiftDataPlannerRepository(context: container.mainContext)
    }

    override func tearDown() {
        repository = nil
        container = nil
    }

    // MARK: Add and fetch

    func testAddTrimsAndFetchOrdersByDayThenCreation() throws {
        let monday = LocalDay(year: 2026, month: 8, day: 17)
        let week = TestFixtures.mondayFirstWeek(start: monday)
        _ = try repository.addTask(text: "  later  ", on: monday, createdAt: Date(timeIntervalSince1970: 2))
        _ = try repository.addTask(text: "first", on: monday, createdAt: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(try repository.fetchTasks(in: week).map(\.text), ["first", "later"])
    }

    func testAddRejectsEmptyOrWhitespaceText() {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        XCTAssertThrowsError(try repository.addTask(text: "   \n", on: day, createdAt: .now)) { error in
            XCTAssertEqual(error as? PlannerError, .persistence(operation: .add))
        }
        XCTAssertEqual(try repository.fetchTasks(in: TestFixtures.mondayFirstWeek(start: day)).count, 0)
    }

    func testFetchReturnsOnlyRequestedWeek() throws {
        let week = TestFixtures.mondayFirstWeek(start: LocalDay(year: 2026, month: 8, day: 17))
        _ = try repository.addTask(text: "before", on: LocalDay(year: 2026, month: 8, day: 16), createdAt: .now)
        _ = try repository.addTask(text: "start", on: LocalDay(year: 2026, month: 8, day: 17), createdAt: .now)
        _ = try repository.addTask(text: "end", on: LocalDay(year: 2026, month: 8, day: 23), createdAt: .now)
        _ = try repository.addTask(text: "after", on: LocalDay(year: 2026, month: 8, day: 24), createdAt: .now)
        XCTAssertEqual(try repository.fetchTasks(in: week).map(\.text), ["start", "end"])
    }

    func testFetchOrdersByDayThenCreationThenIdentifier() throws {
        let week = TestFixtures.mondayFirstWeek(start: LocalDay(year: 2026, month: 8, day: 17))
        let sameInstant = Date(timeIntervalSince1970: 100)
        let wednesday = LocalDay(year: 2026, month: 8, day: 19)
        let tuesday = LocalDay(year: 2026, month: 8, day: 18)
        let a = try repository.addTask(text: "wed-a", on: wednesday, createdAt: sameInstant)
        let b = try repository.addTask(text: "wed-b", on: wednesday, createdAt: sameInstant)
        _ = try repository.addTask(text: "tue", on: tuesday, createdAt: Date(timeIntervalSince1970: 500))

        let fetched = try repository.fetchTasks(in: week)
        XCTAssertEqual(fetched.first?.text, "tue")
        let expectedTail = [a, b].sorted { $0.id.uuidString < $1.id.uuidString }.map(\.text)
        XCTAssertEqual(Array(fetched.dropFirst().map(\.text)), expectedTail)
        XCTAssertEqual(try repository.fetchTasks(in: week).map(\.id), fetched.map(\.id), "Ordering is stable across fetches")
    }

    // MARK: Edit

    func testEditPreservesIdentityAndTaskMetadata() throws {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let original = try repository.addTask(text: "draft", on: day, createdAt: .distantPast)
        let edited = try repository.updateTask(id: original.id, text: " final ")
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.text, "final")
        XCTAssertEqual(edited.day, original.day)
        XCTAssertEqual(edited.createdAt, original.createdAt)
        XCTAssertEqual(edited.isCompleted, original.isCompleted)
    }

    func testEditRejectsEmptyTextAndKeepsOriginal() throws {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let original = try repository.addTask(text: "keep", on: day, createdAt: .now)
        XCTAssertThrowsError(try repository.updateTask(id: original.id, text: "  ")) { error in
            XCTAssertEqual(error as? PlannerError, .persistence(operation: .update))
        }
        XCTAssertEqual(try repository.fetchTasks(in: TestFixtures.mondayFirstWeek(start: day)).map(\.text), ["keep"])
    }

    func testEditUnknownIdentifierFails() {
        XCTAssertThrowsError(try repository.updateTask(id: UUID(), text: "ghost")) { error in
            XCTAssertEqual(error as? PlannerError, .persistence(operation: .update))
        }
    }

    // MARK: Toggle

    func testToggleChangesOnlyCompletion() throws {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let original = try repository.addTask(text: "toggle", on: day, createdAt: .distantPast)
        let completed = try repository.toggleCompletion(id: original.id)
        XCTAssertTrue(completed.isCompleted)
        XCTAssertEqual(completed.text, original.text)
        XCTAssertEqual(completed.day, original.day)
        XCTAssertEqual(completed.createdAt, original.createdAt)
        let reverted = try repository.toggleCompletion(id: original.id)
        XCTAssertFalse(reverted.isCompleted)
    }

    // MARK: Delete

    func testDeleteRemovesExactlyOneIdentifier() throws {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let first = try repository.addTask(text: "first", on: day, createdAt: Date(timeIntervalSince1970: 1))
        let second = try repository.addTask(text: "second", on: day, createdAt: Date(timeIntervalSince1970: 2))
        try repository.deleteTask(id: first.id)
        XCTAssertEqual(try repository.fetchTasks(in: TestFixtures.mondayFirstWeek(start: day)).map(\.id), [second.id])
        XCTAssertThrowsError(try repository.deleteTask(id: first.id)) { error in
            XCTAssertEqual(error as? PlannerError, .persistence(operation: .delete))
        }
    }

    // MARK: Retention

    func testDeleteBeforeRetainsCutoffDay() throws {
        _ = try repository.addTask(text: "expired", on: .init(year: 2026, month: 6, day: 17), createdAt: .distantPast)
        _ = try repository.addTask(text: "kept", on: .init(year: 2026, month: 6, day: 18), createdAt: .distantPast)
        XCTAssertEqual(try repository.deleteTasks(before: .init(year: 2026, month: 6, day: 18)), 1)
        let june = TestFixtures.mondayFirstWeek(start: LocalDay(year: 2026, month: 6, day: 15))
        XCTAssertEqual(try repository.fetchTasks(in: june).map(\.text), ["kept"])
    }

    func testDeleteBeforeNeverRemovesFutureOrCompletedRecentTasks() throws {
        _ = try repository.addTask(text: "old", on: .init(year: 2025, month: 1, day: 1), createdAt: .distantPast)
        let recent = try repository.addTask(text: "recent", on: .init(year: 2026, month: 7, day: 1), createdAt: .distantPast)
        _ = try repository.toggleCompletion(id: recent.id)
        _ = try repository.addTask(text: "future", on: .init(year: 2027, month: 1, day: 1), createdAt: .distantPast)
        XCTAssertEqual(try repository.deleteTasks(before: .init(year: 2026, month: 6, day: 18)), 1)
        XCTAssertEqual(try repository.deleteTasks(before: .init(year: 2026, month: 6, day: 18)), 0)
    }

    // MARK: Error mapping

    func testSaveFailuresMapToOperationSpecificErrors() throws {
        struct Boom: Error {}
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let seeded = try repository.addTask(text: "seed", on: day, createdAt: .now)

        let failing = SwiftDataPlannerRepository(context: container.mainContext, save: { throw Boom() })
        XCTAssertThrowsError(try failing.addTask(text: "new", on: day, createdAt: .now)) {
            XCTAssertEqual($0 as? PlannerError, .persistence(operation: .add))
        }
        XCTAssertThrowsError(try failing.updateTask(id: seeded.id, text: "changed")) {
            XCTAssertEqual($0 as? PlannerError, .persistence(operation: .update))
        }
        XCTAssertThrowsError(try failing.toggleCompletion(id: seeded.id)) {
            XCTAssertEqual($0 as? PlannerError, .persistence(operation: .toggle))
        }
        XCTAssertThrowsError(try failing.deleteTask(id: seeded.id)) {
            XCTAssertEqual($0 as? PlannerError, .persistence(operation: .delete))
        }
        XCTAssertThrowsError(try failing.deleteTasks(before: LocalDay(year: 2027, month: 1, day: 1))) {
            XCTAssertEqual($0 as? PlannerError, .persistence(operation: .retention))
        }

        // Rolled back state remains the last saved state.
        let tasks = try repository.fetchTasks(in: TestFixtures.mondayFirstWeek(start: day))
        XCTAssertEqual(tasks.map(\.text), ["seed"])
        XCTAssertEqual(tasks.first?.isCompleted, false)
    }
}
