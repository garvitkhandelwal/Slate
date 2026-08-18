#if DEBUG
import Foundation

/// DEBUG-only launch-argument switches for UI tests: an isolated store, optional reset, and named seeds.
/// Release builds compile none of this and always use the production store.
enum UITestBootstrap {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-ui-testing") }
    static var resetsStore: Bool { ProcessInfo.processInfo.arguments.contains("-reset-ui-store") }
    static var seedsExpiredTask: Bool { ProcessInfo.processInfo.arguments.contains("-seed-expired-task") }
    static var seedsWallpaper: Bool { ProcessInfo.processInfo.arguments.contains("-seed-wallpaper") }

    /// The retention day key lives beside the store so a reset launch behaves like a first launch.
    static let defaultsSuite = "com.garvit.Slate.uitests"

    static func defaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsSuite) ?? .standard
        if resetsStore { defaults.removePersistentDomain(forName: defaultsSuite) }
        return defaults
    }

    /// Seeds only through the repository and only for the named argument.
    @MainActor
    static func seed(repository: any PlannerRepository, calendarService: CalendarService, now: Date) throws {
        guard seedsExpiredTask else { return }
        let today = LocalDay(date: now, calendar: calendarService.calendar)
        let expiredDay = calendarService.addingDays(-45, to: today)
        _ = try repository.addTask(text: "Expired seed task", on: expiredDay, createdAt: now)
    }
}
#endif
