import Foundation

/// Persistence contract for the single optional wallpaper. File existence is the source of truth.
protocol WallpaperStoring: Sendable {
    func load() async throws -> Data?
    func saveImportedImage(_ data: Data) async throws
    func remove() async throws
}
