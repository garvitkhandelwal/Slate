import Foundation

/// Exactly seven consecutive calendar days in display order, starting on the locale's first weekday.
struct WeekInterval: Equatable, Hashable, Sendable {
    let start: LocalDay
    let days: [LocalDay]

    init(start: LocalDay, days: [LocalDay]) {
        precondition(days.count == 7 && days.first == start, "A week interval holds exactly seven days beginning at start.")
        self.start = start
        self.days = days
    }

    var end: LocalDay { days[6] }
}
