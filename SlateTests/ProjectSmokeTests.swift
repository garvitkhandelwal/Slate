import XCTest
@testable import Slate

final class ProjectSmokeTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertEqual(String(describing: SlateApp.self), "SlateApp")
    }
}
