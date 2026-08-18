import UIKit
import XCTest
@testable import Slate

@MainActor
final class PlannerViewModelTests: XCTestCase {
    // MARK: Startup and navigation

    func testInitDerivesDisplayedWeekWithoutTouchingRepository() {
        let harness = PlannerHarness(now: TestFixtures.august19)
        XCTAssertEqual(harness.model.displayedWeek.start, LocalDay(year: 2026, month: 8, day: 17))
        XCTAssertEqual(harness.model.tasksByDay.count, 7)
        XCTAssertTrue(harness.model.tasksByDay.values.allSatisfy(\.isEmpty))
        XCTAssertTrue(harness.repository.calls.isEmpty)
    }

    func testStartPurgesBeforeFetchingDisplayedWeek() async {
        let harness = PlannerHarness(now: TestFixtures.august19)
        await harness.model.start()
        XCTAssertEqual(Array(harness.repository.callNames.prefix(2)), ["deleteBefore", "fetchWeek"])
        XCTAssertEqual(harness.repository.deleteBeforeCutoffs, [LocalDay(year: 2026, month: 7, day: 20)])
        XCTAssertEqual(harness.model.displayedWeek.start, LocalDay(year: 2026, month: 8, day: 17))
        XCTAssertEqual(harness.defaults.string(forKey: RetentionService.successfulDayKey), "2026-08-19")
    }

    func testStartLoadsWallpaperIndependentlyAfterFetch() async throws {
        let harness = PlannerHarness(now: TestFixtures.august19, wallpaperData: try ImageFixtures.png(width: 4, height: 4))
        await harness.model.start()
        let storeCalls = await harness.wallpaperStore.calls
        XCTAssertEqual(storeCalls, [.load])
        XCTAssertNotNil(harness.model.wallpaperImage)
        XCTAssertEqual(harness.repository.callNames, ["deleteBefore", "fetchWeek"])
    }

    func testStartWithFailedPurgeStillLoadsWeekSilently() async {
        let harness = PlannerHarness(now: TestFixtures.august19, tasks: [.fixture(text: "keep")], repositoryError: .persistence(operation: .retention))
        await harness.model.start()
        XCTAssertNil(harness.model.presentedError, "Retention is silent")
        XCTAssertEqual(harness.model.tasks(on: LocalDay(year: 2026, month: 8, day: 19)).map(\.text), ["keep"])
        XCTAssertNil(harness.defaults.string(forKey: RetentionService.successfulDayKey))
    }

    func testStartFetchGroupsTasksByDayWithEmptyDays() async {
        let wednesday = LocalDay(year: 2026, month: 8, day: 19)
        let friday = LocalDay(year: 2026, month: 8, day: 21)
        let harness = PlannerHarness(tasks: [.fixture(text: "a", day: wednesday), .fixture(text: "b", day: friday), .fixture(text: "old", day: LocalDay(year: 2026, month: 8, day: 1))])
        await harness.model.start()
        XCTAssertEqual(harness.model.tasksByDay.count, 7)
        XCTAssertEqual(harness.model.tasks(on: wednesday).map(\.text), ["a"])
        XCTAssertEqual(harness.model.tasks(on: friday).map(\.text), ["b"])
        XCTAssertEqual(harness.model.tasks(on: LocalDay(year: 2026, month: 8, day: 17)), [])
    }

    func testPreviousNextAndSelectRefreshCorrectWeeks() {
        let harness = PlannerHarness(now: TestFixtures.august19)
        harness.model.showNextWeek()
        XCTAssertEqual(harness.model.displayedWeek.start, LocalDay(year: 2026, month: 8, day: 24))
        harness.model.showPreviousWeek()
        harness.model.showPreviousWeek()
        XCTAssertEqual(harness.model.displayedWeek.start, LocalDay(year: 2026, month: 8, day: 10))
        harness.model.isWeekPickerExpanded = true
        harness.model.selectWeek(containing: LocalDay(year: 2026, month: 12, day: 31))
        XCTAssertEqual(harness.model.displayedWeek.start, LocalDay(year: 2026, month: 12, day: 28))
        XCTAssertFalse(harness.model.isWeekPickerExpanded)
        XCTAssertEqual(harness.repository.calls.count, 4)
        XCTAssertTrue(harness.repository.calls.allSatisfy { $0 == .fetchWeek })
    }

    func testPickerWeeksCenterOnDisplayedWeek() {
        let harness = PlannerHarness(now: TestFixtures.august19)
        XCTAssertEqual(harness.model.pickerWeeks.count, 17)
        XCTAssertEqual(harness.model.pickerWeeks[8], harness.model.displayedWeek)
        XCTAssertEqual(harness.model.currentWeek, harness.model.displayedWeek)
        harness.model.showNextWeek()
        XCTAssertEqual(harness.model.pickerWeeks[8], harness.model.displayedWeek)
        XCTAssertNotEqual(harness.model.currentWeek, harness.model.displayedWeek)
    }

    func testOpenDayUsesSharedRouteState() {
        let harness = PlannerHarness(now: TestFixtures.august19)
        let day = LocalDay(year: 2026, month: 8, day: 20)
        harness.model.openDay(day)
        XCTAssertEqual(harness.model.route, [.day(day)])
    }

    func testFetchErrorPreservesLastTasksAndPresentsError() async {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let harness = PlannerHarness(tasks: [.fixture(text: "kept", day: day)])
        await harness.model.start()
        harness.repository.nextError = .persistence(operation: .fetch)
        harness.model.reloadDisplayedWeek()
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["kept"])
        XCTAssertEqual(harness.model.presentedError, .persistence(operation: .fetch))
    }

    func testSceneActivationRecomputesWeekThroughCalendar() {
        let harness = PlannerHarness(now: TestFixtures.august19)
        harness.model.showNextWeek()
        harness.model.handleSceneActivation()
        XCTAssertEqual(harness.model.displayedWeek.start, LocalDay(year: 2026, month: 8, day: 24))
        XCTAssertEqual(harness.model.tasksByDay.count, 7)
    }

    func testTodayReflectsInjectedClock() {
        let harness = PlannerHarness(now: TestFixtures.august19)
        XCTAssertTrue(harness.model.isToday(LocalDay(year: 2026, month: 8, day: 19)))
        XCTAssertFalse(harness.model.isToday(LocalDay(year: 2026, month: 8, day: 18)))
    }

    // MARK: Capture

    func testRapidAddPersistsTrimmedTextAndKeepsEmptyAddingSession() {
        let harness = PlannerHarness()
        let day = harness.model.displayedWeek.days[0]
        harness.model.beginAdding(on: day)
        harness.model.updateDraft("  Call Sam  ")
        harness.model.submitCapture(keepAdding: true)
        XCTAssertEqual(harness.repository.tasks.map(\.text), ["Call Sam"])
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["Call Sam"])
        XCTAssertEqual(harness.model.capture, .adding(day: day, draft: ""))
        XCTAssertTrue(harness.haptics.events.isEmpty, "Adding produces no haptic")
    }

    func testRapidAddKeepsCreationOrder() {
        let harness = PlannerHarness()
        let day = harness.model.displayedWeek.days[2]
        harness.model.beginAdding(on: day)
        for text in ["one", "two", "three"] {
            harness.model.updateDraft(text)
            harness.model.submitCapture(keepAdding: true)
        }
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["one", "two", "three"])
        XCTAssertEqual(harness.model.capture, .adding(day: day, draft: ""))
    }

    func testEmptySubmitExitsWithoutCreating() {
        let harness = PlannerHarness()
        let day = harness.model.displayedWeek.days[0]
        harness.model.beginAdding(on: day)
        harness.model.updateDraft("   ")
        harness.model.submitCapture(keepAdding: true)
        XCTAssertEqual(harness.model.capture, .none)
        XCTAssertTrue(harness.repository.tasks.isEmpty)
        XCTAssertFalse(harness.repository.calls.contains(.add))
    }

    func testOutsideTapCommitsNonEmptyDraftAndExits() {
        let harness = PlannerHarness()
        let day = harness.model.displayedWeek.days[1]
        harness.model.beginAdding(on: day)
        harness.model.updateDraft("Buy milk")
        harness.model.dismissCapture(committing: true)
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["Buy milk"])
        XCTAssertEqual(harness.model.capture, .none)
    }

    func testOutsideTapWithEmptyDraftDismissesSilently() {
        let harness = PlannerHarness()
        let day = harness.model.displayedWeek.days[1]
        harness.model.beginAdding(on: day)
        harness.model.dismissCapture(committing: true)
        XCTAssertEqual(harness.model.capture, .none)
        XCTAssertTrue(harness.repository.tasks.isEmpty)
    }

    func testDiscardingDismissDropsDraft() {
        let harness = PlannerHarness()
        let day = harness.model.displayedWeek.days[1]
        harness.model.beginAdding(on: day)
        harness.model.updateDraft("Never saved")
        harness.model.dismissCapture(committing: false)
        XCTAssertEqual(harness.model.capture, .none)
        XCTAssertTrue(harness.repository.tasks.isEmpty)
    }

    func testStartingCaptureElsewhereCommitsCurrentDraftFirst() {
        let harness = PlannerHarness()
        let monday = harness.model.displayedWeek.days[0]
        let tuesday = harness.model.displayedWeek.days[1]
        harness.model.beginAdding(on: monday)
        harness.model.updateDraft("Monday task")
        harness.model.beginAdding(on: tuesday)
        XCTAssertEqual(harness.model.tasks(on: monday).map(\.text), ["Monday task"])
        XCTAssertEqual(harness.model.capture, .adding(day: tuesday, draft: ""))
    }

    func testEmptyAddDraftDisappearsWhenCaptureMoves() {
        let harness = PlannerHarness()
        let monday = harness.model.displayedWeek.days[0]
        let tuesday = harness.model.displayedWeek.days[1]
        harness.model.beginAdding(on: monday)
        harness.model.beginAdding(on: tuesday)
        XCTAssertEqual(harness.model.capture, .adding(day: tuesday, draft: ""))
        XCTAssertTrue(harness.repository.tasks.isEmpty)
    }

    func testAddToEditTransitionCommitsValidAdd() async {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let existing = TaskSnapshot.fixture(text: "Existing", day: day)
        let harness = PlannerHarness(tasks: [existing])
        await harness.model.start()
        harness.model.beginAdding(on: day)
        harness.model.updateDraft("New one")
        harness.model.beginEditing(existing)
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["Existing", "New one"].sorted(by: { lhs, rhs in
            let l = harness.model.tasks(on: day).first { $0.text == lhs }!
            let r = harness.model.tasks(on: day).first { $0.text == rhs }!
            return (l.createdAt, l.id.uuidString) < (r.createdAt, r.id.uuidString)
        }))
        XCTAssertEqual(harness.model.capture, .editing(task: existing, draft: "Existing"))
    }

    func testEditToAddTransitionCommitsValidEdit() async {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let existing = TaskSnapshot.fixture(text: "Draft", day: day)
        let harness = PlannerHarness(tasks: [existing])
        await harness.model.start()
        harness.model.beginEditing(existing)
        harness.model.updateDraft("Final")
        harness.model.beginAdding(on: day)
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["Final"])
        XCTAssertEqual(harness.model.tasks(on: day).first?.id, existing.id)
        XCTAssertEqual(harness.model.capture, .adding(day: day, draft: ""))
    }

    func testEditPersistsTrimmedTextAndExits() async {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let existing = TaskSnapshot.fixture(text: "Draft", day: day)
        let harness = PlannerHarness(tasks: [existing])
        await harness.model.start()
        harness.model.beginEditing(existing)
        harness.model.updateDraft("  Final  ")
        harness.model.submitCapture(keepAdding: false)
        XCTAssertEqual(harness.repository.tasks[0].text, "Final")
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["Final"])
        XCTAssertEqual(harness.model.capture, .none)
    }

    func testEmptyEditKeepsOriginalAndExits() async {
        let harness = PlannerHarness(tasks: [.fixture(text: "Keep me")])
        await harness.model.start()
        harness.model.beginEditing(harness.repository.tasks[0])
        harness.model.updateDraft("   ")
        harness.model.submitCapture(keepAdding: false)
        XCTAssertEqual(harness.repository.tasks[0].text, "Keep me")
        XCTAssertEqual(harness.model.capture, .none)
        XCTAssertFalse(harness.repository.calls.contains(.update))
    }

    func testUnchangedEditExitsWithoutPersistence() async {
        let harness = PlannerHarness(tasks: [.fixture(text: "Same")])
        await harness.model.start()
        harness.model.beginEditing(harness.repository.tasks[0])
        harness.model.submitCapture(keepAdding: false)
        XCTAssertEqual(harness.model.capture, .none)
        XCTAssertFalse(harness.repository.calls.contains(.update))
    }

    func testFailedAddKeepsDraftAndDoesNotHaptic() {
        let harness = PlannerHarness(repositoryError: .persistence(operation: .add))
        let day = harness.model.displayedWeek.days[0]
        harness.model.beginAdding(on: day)
        harness.model.updateDraft("Retry me")
        harness.model.submitCapture(keepAdding: true)
        XCTAssertEqual(harness.model.capture, .adding(day: day, draft: "Retry me"))
        XCTAssertEqual(harness.model.presentedError, .persistence(operation: .add))
        XCTAssertTrue(harness.haptics.events.isEmpty)
        XCTAssertTrue(harness.model.tasks(on: day).isEmpty)

        harness.model.presentedError = nil
        harness.model.submitCapture(keepAdding: true)
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["Retry me"], "The retained draft can be retried")
        XCTAssertEqual(harness.model.capture, .adding(day: day, draft: ""))
    }

    func testFailedEditRetainsFieldAndDraft() async {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let existing = TaskSnapshot.fixture(text: "Original", day: day)
        let harness = PlannerHarness(tasks: [existing])
        await harness.model.start()
        harness.model.beginEditing(existing)
        harness.model.updateDraft("Changed")
        harness.repository.nextError = .persistence(operation: .update)
        harness.model.submitCapture(keepAdding: false)
        XCTAssertEqual(harness.model.capture, .editing(task: existing, draft: "Changed"))
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["Original"])
        XCTAssertEqual(harness.model.presentedError, .persistence(operation: .update))
    }

    func testFailedCommitBlocksNavigationAndKeepsSession() {
        let harness = PlannerHarness(repositoryError: .persistence(operation: .add))
        let day = harness.model.displayedWeek.days[0]
        harness.model.beginAdding(on: day)
        harness.model.updateDraft("Pending")
        harness.model.openDay(day)
        XCTAssertEqual(harness.model.route, [])
        XCTAssertEqual(harness.model.capture, .adding(day: day, draft: "Pending"))
    }

    // MARK: Completion and deletion

    func testToggleUpdatesStateAndFiresLightHapticAfterSuccess() async {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let task = TaskSnapshot.fixture(text: "Toggle", day: day)
        let harness = PlannerHarness(tasks: [task])
        await harness.model.start()
        harness.model.toggleTask(task.id)
        XCTAssertEqual(harness.model.tasks(on: day).first?.isCompleted, true)
        XCTAssertEqual(harness.haptics.events, [.light])
        harness.model.toggleTask(task.id)
        XCTAssertEqual(harness.model.tasks(on: day).first?.isCompleted, false)
        XCTAssertEqual(harness.haptics.events, [.light, .light])
    }

    func testFailedToggleRestoresPreviousStateWithoutHaptic() async {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let task = TaskSnapshot.fixture(text: "Toggle", day: day)
        let harness = PlannerHarness(tasks: [task])
        await harness.model.start()
        harness.repository.nextError = .persistence(operation: .toggle)
        harness.model.toggleTask(task.id)
        XCTAssertEqual(harness.model.tasks(on: day).first?.isCompleted, false)
        XCTAssertEqual(harness.model.presentedError, .persistence(operation: .toggle))
        XCTAssertTrue(harness.haptics.events.isEmpty)
    }

    func testDeleteRemovesRowAndFiresMediumHapticAfterSuccess() async {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let first = TaskSnapshot.fixture(text: "First", day: day, createdAt: Date(timeIntervalSince1970: 1))
        let second = TaskSnapshot.fixture(text: "Second", day: day, createdAt: Date(timeIntervalSince1970: 2))
        let harness = PlannerHarness(tasks: [first, second])
        await harness.model.start()
        harness.model.deleteTask(first.id)
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["Second"])
        XCTAssertEqual(harness.haptics.events, [.medium])
    }

    func testFailedDeleteKeepsRowAndPresentsError() async {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let task = TaskSnapshot.fixture(text: "Stay", day: day)
        let harness = PlannerHarness(tasks: [task])
        await harness.model.start()
        harness.repository.nextError = .persistence(operation: .delete)
        harness.model.deleteTask(task.id)
        XCTAssertEqual(harness.model.tasks(on: day).map(\.text), ["Stay"])
        XCTAssertEqual(harness.model.presentedError, .persistence(operation: .delete))
        XCTAssertTrue(harness.haptics.events.isEmpty)
    }

    // MARK: Wallpaper

    func testSuccessfulImportSavesBeforeStateChanges() async throws {
        let harness = PlannerHarness()
        await harness.model.start()
        XCTAssertNil(harness.model.wallpaperImage)
        await harness.model.importWallpaper(data: try ImageFixtures.png(width: 8, height: 8))
        let calls = await harness.wallpaperStore.calls
        XCTAssertEqual(calls, [.load, .save, .load], "The visible image is decoded from the persisted copy after saving")
        XCTAssertNotNil(harness.model.wallpaperImage)
        XCTAssertNil(harness.model.presentedError)
    }

    func testFailedImportPreservesPriorImageAndRaisesImportError() async throws {
        let harness = PlannerHarness(wallpaperData: try ImageFixtures.png(width: 8, height: 8))
        await harness.model.start()
        let prior = harness.model.wallpaperImage
        XCTAssertNotNil(prior)
        await harness.wallpaperStore.setSaveError(.wallpaperImport)
        await harness.model.importWallpaper(data: Data("garbage".utf8))
        XCTAssertTrue(harness.model.wallpaperImage === prior)
        XCTAssertEqual(harness.model.presentedError, .wallpaperImport)
    }

    func testSuccessfulRemovalClearsStateAfterDiskRemoval() async throws {
        let harness = PlannerHarness(wallpaperData: try ImageFixtures.png(width: 8, height: 8))
        await harness.model.start()
        XCTAssertNotNil(harness.model.wallpaperImage)
        await harness.model.removeWallpaper()
        XCTAssertNil(harness.model.wallpaperImage)
        let stored = await harness.wallpaperStore.stored
        XCTAssertNil(stored)
        XCTAssertNil(harness.model.presentedError)
    }

    func testFailedRemovalPreservesStateAndRaisesStorageError() async throws {
        let harness = PlannerHarness(wallpaperData: try ImageFixtures.png(width: 8, height: 8))
        await harness.model.start()
        await harness.wallpaperStore.setRemoveError(.wallpaperStorage)
        await harness.model.removeWallpaper()
        XCTAssertNotNil(harness.model.wallpaperImage)
        XCTAssertEqual(harness.model.presentedError, .wallpaperStorage)
    }

    func testCorruptStoredDataIsRemovedSilently() async {
        let harness = PlannerHarness(wallpaperData: Data("not an image".utf8))
        await harness.model.start()
        XCTAssertNil(harness.model.wallpaperImage)
        XCTAssertNil(harness.model.presentedError, "Corrupt wallpaper never alerts")
        let calls = await harness.wallpaperStore.calls
        XCTAssertEqual(calls, [.load, .remove])
        let stored = await harness.wallpaperStore.stored
        XCTAssertNil(stored)
    }

    func testDeletingTaskBeingEditedEndsCapture() async {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let task = TaskSnapshot.fixture(text: "Editing", day: day)
        let harness = PlannerHarness(tasks: [task])
        await harness.model.start()
        harness.model.beginEditing(task)
        harness.model.deleteTask(task.id)
        XCTAssertEqual(harness.model.capture, .none)
        XCTAssertTrue(harness.model.tasks(on: day).isEmpty)
    }
}
