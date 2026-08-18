import SwiftUI
import XCTest
@testable import Slate

final class WeekSwipeGestureTests: XCTestCase {
    func testHorizontalThresholdAndVerticalRejection() {
        XCTAssertEqual(WeekSwipeGesture.decision(width: -61, height: 8, direction: .leftToRight), .next)
        XCTAssertEqual(WeekSwipeGesture.decision(width: 61, height: 8, direction: .leftToRight), .previous)
        XCTAssertEqual(WeekSwipeGesture.decision(width: -90, height: 120, direction: .leftToRight), .none)
        XCTAssertEqual(WeekSwipeGesture.decision(width: -30, height: 2, direction: .leftToRight), .none)
    }

    func testExactThresholdAndDominanceBoundaries() {
        XCTAssertEqual(WeekSwipeGesture.decision(width: -60, height: 0, direction: .leftToRight), .next)
        XCTAssertEqual(WeekSwipeGesture.decision(width: -59.9, height: 0, direction: .leftToRight), .none)
        // 75 * 1.25 = 93.75: 94 wide is dominant, 93 is not.
        XCTAssertEqual(WeekSwipeGesture.decision(width: 94, height: 75, direction: .leftToRight), .previous)
        XCTAssertEqual(WeekSwipeGesture.decision(width: 93, height: 75, direction: .leftToRight), .none)
    }

    func testRightToLeftMirrorsMeaning() {
        XCTAssertEqual(WeekSwipeGesture.decision(width: -61, height: 8, direction: .rightToLeft), .previous)
        XCTAssertEqual(WeekSwipeGesture.decision(width: 61, height: 8, direction: .rightToLeft), .next)
    }
}
