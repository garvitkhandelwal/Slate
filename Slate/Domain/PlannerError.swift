import Foundation

enum PersistenceOperation: String, Equatable, Sendable {
    case fetch, add, update, toggle, delete, retention
}

/// The bounded set of user-facing failures. Messages never include codes, paths, model details, or task text.
enum PlannerError: LocalizedError, Identifiable, Equatable {
    case persistence(operation: PersistenceOperation)
    case wallpaperImport
    case wallpaperStorage
    case unavailableStore

    var id: String { String(describing: self) }

    var errorDescription: String? {
        switch self {
        case .persistence:
            String(localized: "error_persistence", defaultValue: "Slate couldn’t save that change. Try again.")
        case .wallpaperImport:
            String(localized: "error_wallpaper_import", defaultValue: "Slate couldn’t use that photo. Choose another image.")
        case .wallpaperStorage:
            String(localized: "error_wallpaper_storage", defaultValue: "Slate couldn’t remove the wallpaper. Try again.")
        case .unavailableStore:
            String(localized: "error_unavailable_store", defaultValue: "Slate couldn’t open your plans. Close and reopen the app.")
        }
    }
}
