import Foundation

/// Actor-isolated wallpaper persistence under the app's excluded `Slate` directory. Each slot is a fixed
/// file (`Wallpaper/wallpaper-1.heic` … `wallpaper-3.heic`); writes are atomic replacements.
/// A pre-slot `Wallpaper/current.heic` is adopted as slot 0 on first load.
actor DiskWallpaperStore: WallpaperStoring {
    static let legacyRelativePath = "Wallpaper/current.heic"

    private let baseDirectory: URL
    private let processor: WallpaperImageProcessor
    private let fileManager: FileManager

    nonisolated var directoryURL: URL { baseDirectory.appending(path: "Wallpaper", directoryHint: .isDirectory) }
    nonisolated var legacyFileURL: URL { baseDirectory.appending(path: Self.legacyRelativePath) }

    nonisolated static func relativePath(slot: Int) -> String { "Wallpaper/wallpaper-\(slot + 1).heic" }
    nonisolated func fileURL(slot: Int) -> URL { baseDirectory.appending(path: Self.relativePath(slot: slot)) }

    init(baseDirectory: URL, processor: WallpaperImageProcessor = .init(), fileManager: FileManager = .default) {
        self.baseDirectory = baseDirectory
        self.processor = processor
        self.fileManager = fileManager
    }

    func loadAll() async throws -> [Data] {
        try migrateLegacyFileIfNeeded()
        var loaded: [Data] = []
        for slot in 0..<WallpaperSlots.count {
            let url = fileURL(slot: slot)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                loaded.append(try Data(contentsOf: url, options: .mappedIfSafe))
            } catch {
                throw PlannerError.wallpaperStorage
            }
        }
        return loaded
    }

    /// Validates and normalizes the import first (`wallpaperImport` on failure), then replaces the slot
    /// file atomically and re-applies backup exclusion (`wallpaperStorage` on failure).
    func saveImportedImage(_ data: Data, slot: Int) async throws {
        guard (0..<WallpaperSlots.count).contains(slot) else { throw PlannerError.wallpaperStorage }
        let processed = try await processor.process(data)
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let url = fileURL(slot: slot)
            try processed.write(to: url, options: .atomic)
            try ModelContainerFactory.excludeFromBackup(directoryURL)
            try ModelContainerFactory.excludeFromBackup(url)
        } catch {
            throw PlannerError.wallpaperStorage
        }
    }

    /// Deletes the slot and shifts later wallpapers down so stored indices stay contiguous.
    func remove(slot: Int) async throws {
        guard (0..<WallpaperSlots.count).contains(slot) else { return }
        let url = fileURL(slot: slot)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
            var next = slot
            for later in (slot + 1)..<WallpaperSlots.count {
                let laterURL = fileURL(slot: later)
                guard fileManager.fileExists(atPath: laterURL.path) else { continue }
                try fileManager.moveItem(at: laterURL, to: fileURL(slot: next))
                next += 1
            }
        } catch {
            throw PlannerError.wallpaperStorage
        }
    }

    private func migrateLegacyFileIfNeeded() throws {
        guard fileManager.fileExists(atPath: legacyFileURL.path) else { return }
        let target = fileURL(slot: 0)
        do {
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: legacyFileURL)
            } else {
                try fileManager.moveItem(at: legacyFileURL, to: target)
            }
        } catch {
            throw PlannerError.wallpaperStorage
        }
    }
}
