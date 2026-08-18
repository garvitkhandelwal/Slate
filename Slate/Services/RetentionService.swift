import Foundation

/// Coordinates the retention purge through the repository and remembers the last successful local day
/// so activation-time purges do not repeat within one day. A failed purge never advances that day.
@MainActor
final class RetentionService {
    static let successfulDayKey = "lastSuccessfulRetentionDay"

    private let repository: any PlannerRepository
    private let policy: RetentionPolicy
    private let calendarService: CalendarService
    private let defaults: UserDefaults

    init(
        repository: any PlannerRepository,
        policy: RetentionPolicy = .init(),
        calendarService: CalendarService,
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.policy = policy
        self.calendarService = calendarService
        self.defaults = defaults
    }

    /// Unconditional purge used at cold launch before the first planner fetch.
    @discardableResult
    func purgeExpiredTasks(now: Date) throws -> Int {
        let today = LocalDay(date: now, calendar: calendarService.calendar)
        let count = try repository.deleteTasks(before: policy.cutoff(today: today, calendarService: calendarService))
        defaults.set(dayKey(today), forKey: Self.successfulDayKey)
        return count
    }

    /// Purges only when no successful purge has been recorded for the current local day.
    @discardableResult
    func purgeIfNeeded(now: Date) throws -> Int {
        let today = LocalDay(date: now, calendar: calendarService.calendar)
        guard defaults.string(forKey: Self.successfulDayKey) != dayKey(today) else { return 0 }
        return try purgeExpiredTasks(now: now)
    }

    private func dayKey(_ day: LocalDay) -> String {
        String(format: "%04d-%02d-%02d", locale: Locale(identifier: "en_US_POSIX"), day.year, day.month, day.day)
    }
}
