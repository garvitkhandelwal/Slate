import Foundation
import SwiftData

/// The production/test dependency bundle. Views never construct any of these directly.
@MainActor
struct AppEnvironment {
    let repository: any PlannerRepository
    let wallpaperStore: any WallpaperStoring
    let retentionService: RetentionService
    let haptics: any HapticClient
    let dateProvider: any DateProviding
    let calendarService: CalendarService
}

extension AppEnvironment {
    static func production() throws -> AppEnvironment {
        let calendar = CalendarService()
        let dateProvider = SystemDateProvider()
        let container = try Self.container()
        let repository = SwiftDataPlannerRepository(container: container)
        let retention = RetentionService(repository: repository, calendarService: calendar, defaults: Self.defaults())
        #if DEBUG
        if UITestBootstrap.isEnabled {
            try UITestBootstrap.seed(repository: repository, calendarService: calendar, now: dateProvider.now())
        }
        #endif
        return AppEnvironment(
            repository: repository,
            wallpaperStore: NoWallpaperStore(),
            retentionService: retention,
            haptics: SystemHapticClient(),
            dateProvider: dateProvider,
            calendarService: calendar
        )
    }

    /// Release assembly always opens the production store; only DEBUG UI-test launches use the isolated one.
    private static func container() throws -> ModelContainer {
        #if DEBUG
        if UITestBootstrap.isEnabled {
            return try ModelContainerFactory.uiTesting(reset: UITestBootstrap.resetsStore)
        }
        #endif
        return try ModelContainerFactory.production()
    }

    private static func defaults() -> UserDefaults {
        #if DEBUG
        if UITestBootstrap.isEnabled { return UITestBootstrap.defaults() }
        #endif
        return .standard
    }
}
