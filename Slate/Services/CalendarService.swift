import Foundation

/// Locale-aware week and label calculations. All user-facing dates are rebuilt from `LocalDay`
/// components in the injected calendar; persistence never depends on this type.
struct CalendarService: Sendable {
    let calendar: Calendar
    let locale: Locale

    init(calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) {
        self.calendar = calendar
        self.locale = locale
    }

    // MARK: Dates

    func localDate(for day: LocalDay) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))!
    }

    func addingDays(_ count: Int, to day: LocalDay) -> LocalDay {
        LocalDay(date: calendar.date(byAdding: .day, value: count, to: localDate(for: day))!, calendar: calendar)
    }

    func week(containing day: LocalDay) -> WeekInterval {
        let date = localDate(for: day)
        let weekday = calendar.component(.weekday, from: date)
        let delta = (weekday - calendar.firstWeekday + 7) % 7
        let start = addingDays(-delta, to: day)
        return WeekInterval(start: start, days: (0..<7).map { addingDays($0, to: start) })
    }

    func adjacentWeek(from week: WeekInterval, offset: Int) -> WeekInterval {
        self.week(containing: addingDays(offset * 7, to: week.start))
    }

    func pickerWeeks(centeredOn week: WeekInterval) -> [WeekInterval] {
        (-8...8).map { adjacentWeek(from: week, offset: $0) }
    }

    func isToday(_ day: LocalDay, now: Date) -> Bool {
        day == LocalDay(date: now, calendar: calendar)
    }

    // MARK: Labels

    /// Compact range such as `Aug 17–23` or `Aug 31–Sep 6`; the month is not repeated within one month.
    func weekRangeText(_ week: WeekInterval) -> String {
        let start = localDate(for: week.start)
        let end = localDate(for: week.end)
        let startText = start.formatted(style.month(.abbreviated).day())
        let endText: String
        if calendar.isDate(start, equalTo: end, toGranularity: .month) {
            endText = end.formatted(style.day())
        } else {
            endText = end.formatted(style.month(.abbreviated).day())
        }
        return startText + "–" + endText
    }

    /// Full range used for spoken labels, such as `August 17 – August 23, 2026`.
    func weekRangeAccessibilityText(_ week: WeekInterval) -> String {
        let start = localDate(for: week.start).formatted(style.month(.wide).day())
        let end = localDate(for: week.end).formatted(style.month(.wide).day().year())
        return start + " – " + end
    }

    /// Weekly day label such as `Mon 17`.
    func dayLabel(_ day: LocalDay) -> String {
        localDate(for: day).formatted(style.weekday(.abbreviated).day())
    }

    /// Day heading such as `August 19`.
    func dayHeading(_ day: LocalDay) -> String {
        localDate(for: day).formatted(style.month(.wide).day())
    }

    /// Full weekday such as `Wednesday`.
    func weekdayText(_ day: LocalDay) -> String {
        localDate(for: day).formatted(style.weekday(.wide))
    }

    /// Full spoken date such as `Wednesday, August 19, 2026`.
    func fullDateText(_ day: LocalDay) -> String {
        localDate(for: day).formatted(style.weekday(.wide).month(.wide).day().year())
    }

    private var style: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
}
