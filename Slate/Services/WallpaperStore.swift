import Foundation

/// Persistence contract for up to `WallpaperSlots.count` locally stored wallpapers. Stored files are the
/// source of truth; the view model owns which one (if any) is showing.
protocol WallpaperStoring: Sendable {
    /// Every stored wallpaper in slot order, skipping empty slots.
    func loadAll() async throws -> [Data]
    /// Validates, processes, and writes the import into `slot`, replacing any previous file there.
    func saveImportedImage(_ data: Data, slot: Int) async throws
    /// Deletes the wallpaper in `slot`; a missing file is not an error.
    func remove(slot: Int) async throws
}

enum WallpaperSlots {
    /// The design switches among at most three stored photos.
    static let count = 3
}
