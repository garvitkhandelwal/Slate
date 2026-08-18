import XCTest
@testable import Slate

final class CalendarServiceTests: XCTestCase {
    private func gregorian(firstWeekday: Int, timeZone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    func testMondayFirstWeekAndPickerCount() {
        let service = CalendarService(calendar: gregorian(firstWeekday: 2), locale: Locale(identifier: "en_GB"))
        let week = service.week(containing: LocalDay(year: 2026, month: 8, day: 19))
        XCTAssertEqual(week.start, LocalDay(year: 2026, month: 8, day: 17))
        XCTAssertEqual(week.days.count, 7)
        XCTAssertEqual(week.end, LocalDay(year: 2026, month: 8, day: 23))
        XCTAssertEqual(service.pickerWeeks(centeredOn: week).count, 17)
        XCTAssertEqual(service.pickerWeeks(centeredOn: week)[8], week)
        XCTAssertEqual(service.pickerWeeks(centeredOn: week).first?.start, LocalDay(year: 2026, month: 6, day: 22))
        XCTAssertEqual(service.pickerWeeks(centeredOn: week).last?.start, LocalDay(year: 2026, month: 10, day: 12))
    }

    func testWeekContainingItsOwnStartAndEndIsStable() {
        let service = CalendarService(calendar: gregorian(firstWeekday: 2), locale: Locale(identifier: "en_GB"))
        let week = service.week(containing: LocalDay(year: 2026, month: 8, day: 19))
        XCTAssertEqual(service.week(containing: week.start), week)
        XCTAssertEqual(service.week(containing: week.end), week)
    }

    func testSundayFirstWeekCrossesYear() {
        let service = CalendarService(calendar: gregorian(firstWeekday: 1), locale: Locale(identifier: "en_US"))
        let week = service.week(containing: LocalDay(year: 2026, month: 1, day: 1))
        XCTAssertEqual(week.start, LocalDay(year: 2025, month: 12, day: 28))
        XCTAssertEqual(week.end, LocalDay(year: 2026, month: 1, day: 3))
        XCTAssertEqual(service.adjacentWeek(from: week, offset: 1).start, LocalDay(year: 2026, month: 1, day: 4))
        XCTAssertEqual(service.adjacentWeek(from: week, offset: -1).start, LocalDay(year: 2025, month: 12, day: 21))
    }

    func testAddingDaysCrossesLeapDay() {
        let service = CalendarService(calendar: gregorian(firstWeekday: 2), locale: Locale(identifier: "en_US"))
        XCTAssertEqual(service.addingDays(1, to: LocalDay(year: 2024, month: 2, day: 28)), LocalDay(year: 2024, month: 2, day: 29))
        XCTAssertEqual(service.addingDays(1, to: LocalDay(year: 2025, month: 2, day: 28)), LocalDay(year: 2025, month: 3, day: 1))
        XCTAssertEqual(service.addingDays(-30, to: LocalDay(year: 2026, month: 7, day: 18)), LocalDay(year: 2026, month: 6, day: 18))
    }

    func testSameMonthRangeDoesNotRepeatMonth() {
        let service = CalendarService(calendar: gregorian(firstWeekday: 2), locale: Locale(identifier: "en_US"))
        let week = service.week(containing: LocalDay(year: 2026, month: 8, day: 19))
        XCTAssertEqual(service.weekRangeText(week), "Aug 17–23")
    }

    func testCrossMonthRangeRepeatsMonth() {
        let service = CalendarService(calendar: gregorian(firstWeekday: 2), locale: Locale(identifier: "en_US"))
        let week = service.week(containing: LocalDay(year: 2026, month: 8, day: 31))
        XCTAssertEqual(week.start, LocalDay(year: 2026, month: 8, day: 31))
        XCTAssertEqual(service.weekRangeText(week), "Aug 31–Sep 6")
    }

    func testDayLabelsAreLocalised() {
        let service = CalendarService(calendar: gregorian(firstWeekday: 2), locale: Locale(identifier: "en_US"))
        let day = LocalDay(year: 2026, month: 8, day: 19)
        XCTAssertEqual(service.dayLabel(day), "Wed 19")
        XCTAssertEqual(service.dayHeading(day), "August 19")
        XCTAssertEqual(service.weekdayText(day), "Wednesday")
        XCTAssertEqual(service.fullDateText(day), "Wednesday, August 19, 2026")

        let french = CalendarService(calendar: gregorian(firstWeekday: 2), locale: Locale(identifier: "fr_FR"))
        XCTAssertEqual(french.weekdayText(day), "mercredi")
    }

    func testLabelsUseServiceTimeZoneNotProcessTimeZone() {
        // Noon in Los Angeles is after midnight in far-east zones; labels must not drift by a day.
        let service = CalendarService(calendar: gregorian(firstWeekday: 1, timeZone: "America/Los_Angeles"), locale: Locale(identifier: "en_US"))
        XCTAssertEqual(service.dayLabel(LocalDay(year: 2026, month: 8, day: 19)), "Wed 19")
        let kiritimati = CalendarService(calendar: gregorian(firstWeekday: 1, timeZone: "Pacific/Kiritimati"), locale: Locale(identifier: "en_US"))
        XCTAssertEqual(kiritimati.dayLabel(LocalDay(year: 2026, month: 8, day: 19)), "Wed 19")
    }

    func testIsTodayUsesServiceCalendar() {
        let service = CalendarService(calendar: gregorian(firstWeekday: 2), locale: Locale(identifier: "en_US"))
        let now = Calendar.utcGregorian.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 3))!
        XCTAssertTrue(service.isToday(LocalDay(year: 2026, month: 8, day: 19), now: now))
        XCTAssertFalse(service.isToday(LocalDay(year: 2026, month: 8, day: 20), now: now))
    }

    func testReplacingCalendarChangesWeekStart() {
        let monday = CalendarService(calendar: gregorian(firstWeekday: 2), locale: Locale(identifier: "en_GB"))
        let sunday = CalendarService(calendar: gregorian(firstWeekday: 1), locale: Locale(identifier: "en_US"))
        let day = LocalDay(year: 2026, month: 8, day: 19)
        XCTAssertEqual(monday.week(containing: day).start, LocalDay(year: 2026, month: 8, day: 17))
        XCTAssertEqual(sunday.week(containing: day).start, LocalDay(year: 2026, month: 8, day: 16))
    }
}
