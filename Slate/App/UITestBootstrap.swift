#if DEBUG
import Foundation
import SwiftUI
import UIKit

/// DEBUG-only launch-argument switches for UI tests: an isolated store, optional reset, and named seeds.
/// Release builds compile none of this and always use the production store.
enum UITestBootstrap {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-ui-testing") }
    static var resetsStore: Bool { ProcessInfo.processInfo.arguments.contains("-reset-ui-store") }
    static var seedsExpiredTask: Bool { ProcessInfo.processInfo.arguments.contains("-seed-expired-task") }
    static var seedsWallpaper: Bool { ProcessInfo.processInfo.arguments.contains("-seed-wallpaper") }

    /// `-ui-appearance dark|light` forces an appearance for independent light/dark launches.
    static var forcedColorScheme: ColorScheme? {
        switch UserDefaults.standard.string(forKey: "ui-appearance") {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }

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

    /// Writes a generated, already-processed image where the disk store expects it so wallpaper UI tests
    /// never depend on the system photo picker.
    static func seedWallpaper(in baseDirectory: URL) throws {
        guard seedsWallpaper else { return }
        let size = CGSize(width: 900, height: 1600)
        let rendered = UIGraphicsImageRenderer(size: size).pngData { context in
            let colors = [UIColor(white: 0.95, alpha: 1).cgColor, UIColor(white: 0.15, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        let processed = try WallpaperImageProcessor.processSynchronously(rendered)
        let fileURL = baseDirectory.appending(path: DiskWallpaperStore.relativePath)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try processed.write(to: fileURL, options: .atomic)
    }
}
#endif
