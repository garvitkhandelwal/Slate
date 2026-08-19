import XCTest

/// Wallpaper flows run against a DEBUG-only seeded stored image, so no test depends on the system
/// photo picker. The real out-of-process picker remains a manual device check.
final class WallpaperFlowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Long-presses genuine empty weekly ground: the space between the week range and the switch controls.
    private func longPressEmptyGround(in app: XCUIApplication) {
        let range = app.buttons["week-range"]
        let wallpaperSwitch = app.buttons["wallpaper-switch"]
        XCTAssertTrue(range.waitForExistence(timeout: 3))
        XCTAssertTrue(wallpaperSwitch.waitForExistence(timeout: 3))
        let x = (range.frame.maxX + wallpaperSwitch.frame.minX) / 2
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: x, dy: range.frame.midY))
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

    // MARK: Top-of-surface switchers

    func testWallpaperSwitchCyclesSeededWallpaperAndNone() {
        let app = launchResetApp(extraArguments: ["-seed-wallpaper"])
        XCTAssertTrue(app.buttons["week-range"].waitForExistence(timeout: 5))
        let wallpaperSwitch = app.buttons["wallpaper-switch"]
        XCTAssertTrue(wallpaperSwitch.waitForExistence(timeout: 3))
        XCTAssertEqual(wallpaperSwitch.label, "Wallpaper 1 of 1")
        wallpaperSwitch.tap()
        XCTAssertTrue(wallpaperSwitch.wait(forLabel: "Photo"))
        wallpaperSwitch.tap()
        XCTAssertTrue(wallpaperSwitch.wait(forLabel: "Wallpaper 1 of 1"))

        // The choice survives relaunch and is the same on the day view.
        wallpaperSwitch.tap()
        XCTAssertTrue(wallpaperSwitch.wait(forLabel: "Photo"))
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["wallpaper-switch"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["wallpaper-switch"].label, "Photo")
        let label = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "day-label-")).firstMatch
        label.tap()
        XCTAssertTrue(app.dayRoot.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["wallpaper-switch"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["wallpaper-switch"].label, "Photo")
    }

    func testWallpaperSwitchWithNothingStoredOpensPhotoPicker() {
        let app = launchResetApp()
        XCTAssertTrue(app.buttons["wallpaper-switch"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["wallpaper-switch"].label, "Photo")
        app.buttons["wallpaper-switch"].tap()
        // The out-of-process picker presents; its internals are not ours to drive. No permission alert appears.
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2))
    }

    func testAppearanceSwitchFlipsGroundAndPersists() {
        let app = launchResetApp(extraArguments: ["-ui-appearance", "light"])
        let appearanceSwitch = app.buttons["appearance-switch"]
        XCTAssertTrue(appearanceSwitch.waitForExistence(timeout: 5))
        XCTAssertEqual(appearanceSwitch.label, "Switch to dark appearance")
        XCTAssertFalse(app.groundIsDark)
        appearanceSwitch.tap()
        XCTAssertTrue(appearanceSwitch.wait(forLabel: "Switch to light appearance"))
        sleep(1)
        XCTAssertTrue(app.groundIsDark)

        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["appearance-switch"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["appearance-switch"].label, "Switch to light appearance")
        XCTAssertTrue(app.groundIsDark)
    }
}

extension XCUIElement {
    func wait(forLabel label: String, timeout: TimeInterval = 3) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

extension XCUIApplication {
    /// Whether the median screen pixel is darker than mid-gray — the rendered appearance, not a view-model claim.
    var groundIsDark: Bool {
        guard let image = screenshot().image.cgImage, let data = image.dataProvider?.data as Data? else { return false }
        let bytesPerPixel = image.bitsPerPixel / 8
        var samples: [Int] = []
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            var y = image.height / 3
            while y < image.height * 2 / 3 {
                var x = 0
                while x < image.width {
                    let offset = y * image.bytesPerRow + x * bytesPerPixel
                    samples.append((Int(buffer[offset]) + Int(buffer[offset + 1]) + Int(buffer[offset + 2])) / 3)
                    x += 16
                }
                y += 16
            }
        }
        samples.sort()
        return !samples.isEmpty && samples[samples.count / 2] < 128
    }
}
