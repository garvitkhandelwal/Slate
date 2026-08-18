import XCTest

final class NavigationTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = launchResetApp()
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
    }

    private var rangeLabel: String { app.buttons["week-range"].label }
    private var pickerOptions: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "week-option-"))
    }

    private enum Direction { case left, right }

    /// Swipes on the week-range header, which is always visible weekly ground.
    private func swipeWeek(_ direction: Direction) {
        let header = app.buttons["week-range"]
        switch direction {
        case .left: header.swipeLeft(velocity: .fast)
        case .right: header.swipeRight(velocity: .fast)
        }
    }

    private func waitForRange(toChangeFrom previous: String, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "label != %@", previous)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.buttons["week-range"])
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    // MARK: Gestures

    func testLeftAndRightSwipesChangeExactlyOneWeek() {
        let current = rangeLabel
        swipeWeek(.left)
        XCTAssertTrue(waitForRange(toChangeFrom: current))
        let next = rangeLabel
        XCTAssertNotEqual(next, current)

        swipeWeek(.right)
        XCTAssertTrue(waitForRange(toChangeFrom: next))
        XCTAssertEqual(rangeLabel, current, "One swipe back returns to the starting week")

        swipeWeek(.right)
        XCTAssertTrue(waitForRange(toChangeFrom: current))
        XCTAssertNotEqual(rangeLabel, next)
    }

    func testVerticalScrollDoesNotChangeWeek() {
        let current = rangeLabel
        app.swipeUp()
        app.swipeDown()
        XCTAssertFalse(waitForRange(toChangeFrom: current, timeout: 1))
        XCTAssertEqual(rangeLabel, current)
    }

    func testTaskRowSwipeExposesDeleteWithoutChangingWeek() {
        let current = rangeLabel
        let add = app.buttons["add-" + app.todayDayIdentifierSuffix]
        XCTAssertTrue(app.reveal(add))
        add.tap()
        XCTAssertTrue(app.captureField.waitForExistence(timeout: 3))
        app.captureField.typeText("Swipe target\n")
        app.captureField.typeText("\n")
        let row = app.taskRow("Swipe target")
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(rangeLabel, current, "A task swipe never changes the week")
    }

    // MARK: Picker

    func testPickerHasSeventeenChoicesAndCollapsesAfterSelection() {
        let current = rangeLabel
        app.buttons["week-range"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["week-picker"].waitForExistence(timeout: 3))
        XCTAssertEqual(pickerOptions.count, 17)
        XCTAssertTrue(app.buttons["week-option-8"].isSelected, "The displayed week is marked selected")

        let target = app.buttons["week-option-10"]
        XCTAssertTrue(app.reveal(target))
        let targetLabel = target.label
        target.tap()
        XCTAssertTrue(waitForRange(toChangeFrom: current))
        XCTAssertFalse(app.descendants(matching: .any)["week-picker"].exists, "The picker collapses after selection")
        XCTAssertEqual(rangeLabel, targetLabel)
    }

    // MARK: Day route

    func testDayPushUsesSameStateAndBackReturnsToChosenWeek() {
        let current = rangeLabel
        swipeWeek(.left)
        XCTAssertTrue(waitForRange(toChangeFrom: current))
        let chosen = rangeLabel

        let firstLabel = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-label-")).firstMatch
        XCTAssertTrue(firstLabel.waitForExistence(timeout: 3))
        let dayIdentifier = firstLabel.identifier.replacingOccurrences(of: "day-label-", with: "")
        firstLabel.tap()
        XCTAssertTrue(app.dayRoot.waitForExistence(timeout: 3))

        let add = app.buttons["add-" + dayIdentifier]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        add.tap()
        XCTAssertTrue(app.captureField.waitForExistence(timeout: 3))
        app.captureField.typeText("Shared state\n")
        app.captureField.typeText("\n")
        XCTAssertTrue(app.taskRow("Shared state").waitForExistence(timeout: 3))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.plannerRoot.waitForExistence(timeout: 3))
        XCTAssertEqual(rangeLabel, chosen, "Native back returns to the chosen week")
        XCTAssertTrue(app.reveal(app.taskRow("Shared state")), "The week view shows the task added in the day view")
    }

    // MARK: Right to left

    func testRightToLeftMirrorsSwipeMeaning() {
        // Left-to-right: swipe left advances, so option 7 (one before the displayed week) is the start.
        let current = rangeLabel
        swipeWeek(.left)
        XCTAssertTrue(waitForRange(toChangeFrom: current))
        app.buttons["week-range"].tap()
        XCTAssertTrue(app.buttons["week-option-7"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["week-option-7"].label, current)

        // Right-to-left: swipe left goes back, so option 9 (one after the displayed week) is the start.
        app.terminate()
        app = launchResetApp(extraArguments: ["-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES"])
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
        let rtlCurrent = rangeLabel
        swipeWeek(.left)
        XCTAssertTrue(waitForRange(toChangeFrom: rtlCurrent))
        app.buttons["week-range"].tap()
        XCTAssertTrue(app.buttons["week-option-9"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["week-option-9"].label, rtlCurrent)
    }
}
