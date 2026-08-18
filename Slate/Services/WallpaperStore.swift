import Foundation

/// Persistence contract for the single optional wallpaper. File existence is the source of truth.
protocol WallpaperStoring: Sendable {
    func load() async throws -> Data?
    func saveImportedImage(_ data: Data) async throws
    func remove() async throws
}

/// The complete no-wallpaper behavior for pre-wallpaper delivery slices: no image, and imports are refused.
actor NoWallpaperStore: WallpaperStoring {
    func load() async throws -> Data? { nil }
    func saveImportedImage(_ data: Data) async throws { throw PlannerError.wallpaperImport }
    func remove() async throws {}
}
