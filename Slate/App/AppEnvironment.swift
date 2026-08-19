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
    /// Small preferences: appearance override and the showing wallpaper slot (UI-test launches get an isolated suite).
    let defaults: UserDefaults
}

extension AppEnvironment {
    static func production() throws -> AppEnvironment {
        let calendar = CalendarService()
        let dateProvider = SystemDateProvider()
        let container = try Self.container()
        let repository = SwiftDataPlannerRepository(container: container)
        let defaults = Self.defaults()
        let retention = RetentionService(repository: repository, calendarService: calendar, defaults: defaults)
        let wallpaperDirectory = try Self.wallpaperDirectory()
        #if DEBUG
        if UITestBootstrap.isEnabled {
            try UITestBootstrap.seed(repository: repository, calendarService: calendar, now: dateProvider.now())
            try UITestBootstrap.seedWallpaper(in: wallpaperDirectory, defaults: defaults)
            UITestBootstrap.seedPreferences(into: defaults)
        }
        #endif
        return AppEnvironment(
            repository: repository,
            wallpaperStore: DiskWallpaperStore(baseDirectory: wallpaperDirectory),
            retentionService: retention,
            haptics: SystemHapticClient(),
            dateProvider: dateProvider,
            calendarService: calendar,
            defaults: defaults
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

    /// Wallpaper lives beside the store so backup exclusion and UI-test isolation cover both.
    private static func wallpaperDirectory() throws -> URL {
        let base = try ModelContainerFactory.slateSupportDirectory()
        #if DEBUG
        if UITestBootstrap.isEnabled { return base.appending(path: "UITests", directoryHint: .isDirectory) }
        #endif
        return base
    }

    private static func defaults() -> UserDefaults {
        #if DEBUG
        if UITestBootstrap.isEnabled { return UITestBootstrap.defaults() }
        #endif
        return .standard
    }
}
