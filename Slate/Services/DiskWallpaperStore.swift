import Foundation

/// Actor-isolated wallpaper persistence at a fixed path under the app's excluded `Slate` directory.
/// File existence is the source of truth; writes are atomic replacements of `Wallpaper/current.heic`.
actor DiskWallpaperStore: WallpaperStoring {
    static let relativePath = "Wallpaper/current.heic"

    private let baseDirectory: URL
    private let processor: WallpaperImageProcessor
    private let fileManager: FileManager

    nonisolated var fileURL: URL { baseDirectory.appending(path: Self.relativePath) }
    nonisolated var directoryURL: URL { fileURL.deletingLastPathComponent() }

    init(baseDirectory: URL, processor: WallpaperImageProcessor = .init(), fileManager: FileManager = .default) {
        self.baseDirectory = baseDirectory
        self.processor = processor
        self.fileManager = fileManager
    }

    func load() async throws -> Data? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try Data(contentsOf: fileURL, options: .mappedIfSafe)
        } catch {
            throw PlannerError.wallpaperStorage
        }
    }

    /// Validates and normalizes the import first (`wallpaperImport` on failure), then replaces the file
    /// atomically and re-applies backup exclusion (`wallpaperStorage` on failure).
    func saveImportedImage(_ data: Data) async throws {
        let processed = try await processor.process(data)
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try processed.write(to: fileURL, options: .atomic)
            try ModelContainerFactory.excludeFromBackup(directoryURL)
            try ModelContainerFactory.excludeFromBackup(fileURL)
        } catch {
            throw PlannerError.wallpaperStorage
        }
    }

    func remove() async throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw PlannerError.wallpaperStorage
        }
    }
}
