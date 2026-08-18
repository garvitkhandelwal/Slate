import XCTest

final class FirstLaunchTests: XCTestCase {
    func testLaunchesDirectlyIntoPlannerSurface() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-ui-store"]
        app.launch()
        XCTAssertTrue(app.staticTexts["planner-root"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Welcome"].exists)
    }
}
