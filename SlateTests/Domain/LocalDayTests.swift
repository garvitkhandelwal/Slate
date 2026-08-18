import XCTest
@testable import Slate

final class LocalDayTests: XCTestCase {
    func testStorageRoundTripUsesUTCNoon() throws {
        let day = LocalDay(year: 2026, month: 8, day: 19)
        let components = Calendar.utcGregorian.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: day.storageDate)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 19)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(LocalDay(storageDate: day.storageDate), day)
    }

    func testStorageDateDoesNotMoveAcrossLocalTimeZones() {
        let stored = LocalDay(year: 2024, month: 2, day: 29).storageDate
        XCTAssertEqual(LocalDay(storageDate: stored), LocalDay(year: 2024, month: 2, day: 29))

        // Storage decoding ignores the device zone entirely: the same instant decodes identically everywhere,
        // even though a naive local-midnight encoding in these zones would land on a neighbouring day.
        for identifier in ["Pacific/Kiritimati", "Pacific/Pago_Pago", "America/Los_Angeles", "Asia/Kolkata"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: identifier)!
            let localMidnight = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
            let encoded = LocalDay(date: localMidnight, calendar: calendar).storageDate
            XCTAssertEqual(encoded, stored, identifier)
            XCTAssertEqual(LocalDay(storageDate: encoded), LocalDay(year: 2024, month: 2, day: 29), identifier)
        }
    }

    func testComparableCrossesYearBoundary() {
        XCTAssertLessThan(LocalDay(year: 2025, month: 12, day: 31), LocalDay(year: 2026, month: 1, day: 1))
        XCTAssertLessThan(LocalDay(year: 2026, month: 1, day: 31), LocalDay(year: 2026, month: 2, day: 1))
        XCTAssertGreaterThan(LocalDay(year: 2026, month: 3, day: 1), LocalDay(year: 2026, month: 2, day: 28))
    }

    func testLeapDayRoundTrips() {
        let leap = LocalDay(year: 2028, month: 2, day: 29)
        XCTAssertEqual(LocalDay(storageDate: leap.storageDate), leap)
    }

    func testLocalDateInitialiserUsesSuppliedCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!
        // 2026-08-19 23:30 UTC is already 2026-08-20 in UTC+14.
        let instant = Calendar.utcGregorian.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 23, minute: 30))!
        XCTAssertEqual(LocalDay(date: instant, calendar: calendar), LocalDay(year: 2026, month: 8, day: 20))
        XCTAssertEqual(LocalDay(date: instant, calendar: .utcGregorian), LocalDay(year: 2026, month: 8, day: 19))
    }
}
