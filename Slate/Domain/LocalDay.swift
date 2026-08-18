import Foundation

extension Calendar {
    /// A fixed Gregorian calendar in UTC used only for stable date-only persistence.
    static var utcGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

/// A calendar date with no time or time-zone component.
///
/// `storageDate` encodes the components at noon in a fixed UTC Gregorian calendar so a device
/// time-zone change can never move a planned item onto another date.
struct LocalDay: Hashable, Comparable, Sendable, Codable {
    let year: Int
    let month: Int
    let day: Int

    var storageDate: Date {
        Calendar.utcGregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(storageDate: Date) {
        let values = Calendar.utcGregorian.dateComponents([.year, .month, .day], from: storageDate)
        self.init(year: values.year!, month: values.month!, day: values.day!)
    }

    init(date: Date, calendar: Calendar) {
        let values = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: values.year!, month: values.month!, day: values.day!)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
