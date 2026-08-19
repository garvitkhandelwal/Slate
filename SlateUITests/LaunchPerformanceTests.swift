import XCTest

/// Cold-launch metric per the plan. On the iOS 26.5 simulator with Xcode 26.6 the launch metric records no
/// samples, and the wall clock includes XCTest automation setup, so the release figure is measured on device
/// (see docs/qa/SLATE_V1_MEASUREMENTS.md).
final class LaunchPerformanceTests: XCTestCase {
    func testColdLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true), XCTClockMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-reset-ui-store"]
            app.launch()
        }
    }
}
