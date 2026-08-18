import Foundation

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
        let container = try ModelContainerFactory.production()
        let repository = SwiftDataPlannerRepository(context: container.mainContext)
        return AppEnvironment(
            repository: repository,
            wallpaperStore: NoWallpaperStore(),
            retentionService: RetentionService(repository: repository, calendarService: calendar),
            haptics: SystemHapticClient(),
            dateProvider: SystemDateProvider(),
            calendarService: calendar
        )
    }
}
