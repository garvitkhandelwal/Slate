import XCTest

final class TaskFlowTests: XCTestCase {
    private var app: XCUIApplication!
    private var suffix = ""

    override func setUp() {
        continueAfterFailure = false
        suffix = String(UUID().uuidString.prefix(4))
        app = launchResetApp()
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
    }

    private func text(_ base: String) -> String { base + " " + suffix }

    private var todayAdd: XCUIElement { app.buttons["add-" + app.todayDayIdentifierSuffix] }
    private var todayLabel: XCUIElement { app.buttons["day-label-" + app.todayDayIdentifierSuffix] }

    private func beginAddingToday() {
        XCTAssertTrue(app.reveal(todayAdd))
        todayAdd.tap()
        XCTAssertTrue(app.captureField.waitForExistence(timeout: 3))
    }

    // MARK: Add

    func testAddOneTaskAndRapidEntryKeepsFieldFocused() {
        beginAddingToday()
        app.captureField.typeText(text("Buy milk") + "\n")
        XCTAssertTrue(app.taskRow(text("Buy milk")).waitForExistence(timeout: 3))
        XCTAssertTrue(app.captureField.exists, "Rapid entry keeps the field in place")
        XCTAssertEqual(app.captureField.value as? String ?? "", "", "The field is cleared for the next task")

        app.captureField.typeText(text("Two") + "\n")
        app.captureField.typeText(text("Three") + "\n")
        XCTAssertTrue(app.taskRow(text("Two")).waitForExistence(timeout: 3))
        XCTAssertTrue(app.taskRow(text("Three")).exists)
        XCTAssertLessThan(app.taskRow(text("Buy milk")).frame.minY, app.taskRow(text("Two")).frame.minY)
        XCTAssertLessThan(app.taskRow(text("Two")).frame.minY, app.taskRow(text("Three")).frame.minY)
    }

    func testEmptySubmitDismissesFieldWithoutCreating() {
        beginAddingToday()
        app.captureField.typeText("\n")
        XCTAssertFalse(app.captureField.waitForExistence(timeout: 1))
        XCTAssertTrue(todayAdd.exists, "The add affordance returns")
    }

    func testOutsideTapCommitsDraftAndExits() {
        beginAddingToday()
        app.captureField.typeText(text("Committed by tap"))
        // Empty ground to the right of a day label that is visible above the keyboard.
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.frame.maxY
        let visibleLabel = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-label-"))
            .allElementsBoundByIndex
            .first { $0.frame.minY > 40 && $0.frame.maxY < keyboardTop - 8 }
        let label = try! XCTUnwrap(visibleLabel, "A day label should be visible above the keyboard")
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.frame.maxX - 30, dy: label.frame.midY))
            .tap()
        XCTAssertTrue(app.reveal(app.taskRow(text("Committed by tap"))))
        XCTAssertFalse(app.captureField.exists)
    }

    // MARK: Complete

    func testTapTogglesCompletionValue() {
        beginAddingToday()
        app.captureField.typeText(text("Toggle me") + "\n")
        app.captureField.typeText("\n")
        let row = app.taskRow(text("Toggle me"))
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertEqual(row.value as? String, "Not completed")
        row.tap()
        XCTAssertTrue(app.taskRow(text("Toggle me")).wait(forValue: "Completed"))
        app.taskRow(text("Toggle me")).tap()
        XCTAssertTrue(app.taskRow(text("Toggle me")).wait(forValue: "Not completed"))
    }

    // MARK: Day view editing

    func testOpenDayEditFullTextAndReturn() {
        beginAddingToday()
        app.captureField.typeText(text("Draft") + "\n")
        app.captureField.typeText("\n")
        XCTAssertTrue(app.taskRow(text("Draft")).waitForExistence(timeout: 3))

        XCTAssertTrue(app.reveal(todayLabel))
        todayLabel.tap()
        XCTAssertTrue(app.dayRoot.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["day-heading"].exists)
        let dayRow = app.taskRow(text("Draft"))
        XCTAssertTrue(dayRow.waitForExistence(timeout: 3))
        dayRow.tap()
        XCTAssertTrue(app.captureField.waitForExistence(timeout: 3))
        XCTAssertEqual(app.captureField.value as? String, text("Draft"))

        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: text("Draft").count)
        app.captureField.typeText(deletes + text("Final") + "\n")
        XCTAssertTrue(app.taskRow(text("Final")).waitForExistence(timeout: 3))
        XCTAssertFalse(app.taskRow(text("Draft")).exists)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.plannerRoot.waitForExistence(timeout: 3))
        XCTAssertTrue(app.reveal(app.taskRow(text("Final"))))
        XCTAssertFalse(app.taskRow(text("Draft")).exists)
    }

    // MARK: Delete

    func testSwipeRevealsDeleteAndRemovesRow() {
        beginAddingToday()
        app.captureField.typeText(text("Remove me") + "\n")
        app.captureField.typeText("\n")
        let row = app.taskRow(text("Remove me"))
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertFalse(app.taskRow(text("Remove me")).waitForExistence(timeout: 1))
    }

    // MARK: Persistence

    func testTasksPersistAcrossRelaunch() {
        beginAddingToday()
        app.captureField.typeText(text("Persist") + "\n")
        app.captureField.typeText("\n")
        XCTAssertTrue(app.taskRow(text("Persist")).waitForExistence(timeout: 3))

        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.reveal(app.taskRow(text("Persist"))))
    }
}

extension XCUIElement {
    /// Waits for the element's accessibility value to become `value`.
    func wait(forValue value: String, timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

extension XCUIApplication {
    /// `Y-M-D` for the current local day, matching the app's identifiers.
    var todayDayIdentifierSuffix: String {
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year!)-\(components.month!)-\(components.day!)"
    }
}
