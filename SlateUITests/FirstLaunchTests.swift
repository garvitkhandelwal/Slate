import XCTest

final class FirstLaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLaunchesDirectlyIntoPlannerSurface() {
        let app = launchResetApp()
        XCTAssertTrue(app.plannerRoot.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Welcome"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    func testFirstLaunchShowsSevenDaySections() {
        let app = launchResetApp()
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        for identifier in app.currentWeekDayIdentifiers {
            XCTAssertTrue(app.reveal(app.buttons[identifier]), "Missing day label \(identifier)")
        }
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-label-")).count, 7)
    }

    func testFirstLaunchAtAccessibilityTextSizeKeepsAllDaysReachable() {
        let app = launchResetApp(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
        for identifier in app.currentWeekDayIdentifiers {
            XCTAssertTrue(app.reveal(app.buttons[identifier]), "Missing day label \(identifier) at accessibility size")
        }
    }
}

// MARK: - Shared launch and query helpers

extension XCTestCase {
    /// Launches Slate against an isolated, freshly reset UI-test store.
    @discardableResult
    func launchResetApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-ui-store"] + extraArguments
        app.launch()
        return app
    }
}

extension XCUIApplication {
    var plannerRoot: XCUIElement { descendants(matching: .any)["planner-root"].firstMatch }
    var dayRoot: XCUIElement { descendants(matching: .any)["day-root"].firstMatch }
    var captureField: XCUIElement { textFields["capture-field"].firstMatch }

    /// The seven `day-label-Y-M-D` identifiers for the current locale-aware week, computed with the same
    /// autoupdating calendar the app uses.
    var currentWeekDayIdentifiers: [String] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let delta = (weekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -delta, to: today)!
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            return "day-label-\(components.year!)-\(components.month!)-\(components.day!)"
        }
    }

    /// Scrolls the planner until the element exists and is hittable. Returns whether it was found.
    @discardableResult
    func reveal(_ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        if element.waitForExistence(timeout: 1), element.isHittable { return true }
        for _ in 0..<maxSwipes {
            swipeUp(velocity: .slow)
            if element.exists, element.isHittable { return true }
        }
        for _ in 0..<maxSwipes {
            swipeDown(velocity: .slow)
            if element.exists, element.isHittable { return true }
        }
        return element.exists
    }

    /// The combined accessibility element for a task row, found by its visible text.
    func taskRow(_ text: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }
}
