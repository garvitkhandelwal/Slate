import Foundation

/// The rolling retention rule: everything earlier than `today - 30` calendar days is expired.
/// On July 18 the cutoff is June 18; June 17 and earlier are deleted, June 18 remains.
struct RetentionPolicy: Sendable {
    let retentionDays = 30

    func cutoff(today: LocalDay, calendarService: CalendarService) -> LocalDay {
        calendarService.addingDays(-retentionDays, to: today)
    }
}
