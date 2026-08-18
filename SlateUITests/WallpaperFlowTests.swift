import XCTest

/// Wallpaper flows run against a DEBUG-only seeded stored image, so no test depends on the system
/// photo picker. The real out-of-process picker remains a manual device check.
final class WallpaperFlowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Long-presses genuine empty weekly ground: the space to the right of the week range.
    private func longPressEmptyGround(in app: XCUIApplication) {
        let range = app.buttons["week-range"]
        XCTAssertTrue(range.waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.frame.maxX - 30, dy: range.frame.midY))
            .press(forDuration: 0.9)
    }

    /// The system dismisses the compact dialog on an outside tap; there is no bespoke control.
    private func dismissDialog(in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        let gone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: gone, object: app.buttons["Choose photo…"])
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 3), .completed)
    }

    func testLongPressOnEmptyGroundOffersChoosePhotoWithoutRemoveWhenAbsent() {
        let app = launchResetApp()
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
        longPressEmptyGround(in: app)
        XCTAssertTrue(app.buttons["Choose photo…"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Remove wallpaper"].exists, "Removal is offered only when a wallpaper exists")
        dismissDialog(in: app)
        XCTAssertFalse(app.alerts.firstMatch.exists, "No permission prompt appears")
    }

    func testSeededWallpaperCanBeRemovedAndStaysRemovedAcrossRelaunch() {
        let app = launchResetApp(extraArguments: ["-seed-wallpaper"])
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
        longPressEmptyGround(in: app)
        XCTAssertTrue(app.buttons["Remove wallpaper"].waitForExistence(timeout: 3), "A stored wallpaper exposes removal")
        app.buttons["Remove wallpaper"].tap()

        longPressEmptyGround(in: app)
        XCTAssertTrue(app.buttons["Choose photo…"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Remove wallpaper"].exists, "Removal clears the stored file immediately")
        dismissDialog(in: app)

        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
        longPressEmptyGround(in: app)
        XCTAssertTrue(app.buttons["Choose photo…"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Remove wallpaper"].exists, "The removed wallpaper does not return")
        dismissDialog(in: app)
    }

    func testWallpaperDoesNotBlockPlannerInteraction() {
        let app = launchResetApp(extraArguments: ["-seed-wallpaper"])
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
        let add = app.buttons["add-" + app.todayDayIdentifierSuffix]
        XCTAssertTrue(app.reveal(add))
        add.tap()
        XCTAssertTrue(app.captureField.waitForExistence(timeout: 3))
        app.captureField.typeText("On wallpaper\n")
        XCTAssertTrue(app.taskRow("On wallpaper").waitForExistence(timeout: 3))
    }

    func testDecorativeWallpaperHasNoAccessibilityLabel() {
        let app = launchResetApp(extraArguments: ["-seed-wallpaper"])
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
        let labelled = app.images.matching(NSPredicate(format: "label != ''"))
        XCTAssertEqual(labelled.count, 0, "The wallpaper is decorative and announces nothing")
    }
}
