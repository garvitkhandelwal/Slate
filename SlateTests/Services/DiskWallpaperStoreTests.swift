import XCTest
@testable import Slate

final class DiskWallpaperStoreTests: XCTestCase {
    private var baseDirectory: URL!
    private var store: DiskWallpaperStore!

    override func setUpWithError() throws {
        baseDirectory = FileManager.default.temporaryDirectory
            .appending(path: "SlateWallpaperTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        store = DiskWallpaperStore(baseDirectory: baseDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: baseDirectory)
    }

    private var wallpaperDirectory: URL { baseDirectory.appending(path: "Wallpaper", directoryHint: .isDirectory) }
    private var fileURL: URL { wallpaperDirectory.appending(path: "current.heic") }

    private func isExcludedFromBackup(_ url: URL) throws -> Bool {
        try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup ?? false
    }

    func testLoadReturnsNilWhenAbsent() async throws {
        let data = try await store.load()
        XCTAssertNil(data)
    }

    func testSaveWritesFixedFileExcludedFromBackupWithoutLeftovers() async throws {
        try await store.saveImportedImage(try ImageFixtures.png(width: 120, height: 80))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(store.fileURL, fileURL)
        XCTAssertTrue(try isExcludedFromBackup(wallpaperDirectory))
        XCTAssertTrue(try isExcludedFromBackup(fileURL))
        let siblings = try FileManager.default.contentsOfDirectory(atPath: wallpaperDirectory.path)
        XCTAssertEqual(siblings, ["current.heic"], "Atomic writes leave no temporary siblings")

        let loaded = try await store.load()
        XCTAssertEqual(loaded, try Data(contentsOf: fileURL))
    }

    func testSaveReplacesPreviousContent() async throws {
        try await store.saveImportedImage(try ImageFixtures.png(width: 120, height: 80, pattern: .black))
        let first = try await store.load()
        try await store.saveImportedImage(try ImageFixtures.png(width: 300, height: 200, pattern: .white))
        let second = try await store.load()
        XCTAssertNotEqual(first, second)
        let siblings = try FileManager.default.contentsOfDirectory(atPath: wallpaperDirectory.path)
        XCTAssertEqual(siblings, ["current.heic"])
    }

    func testInvalidImportLeavesExistingWallpaperUntouched() async throws {
        try await store.saveImportedImage(try ImageFixtures.png(width: 120, height: 80))
        let before = try await store.load()
        do {
            try await store.saveImportedImage(Data("garbage".utf8))
            XCTFail("Expected import failure")
        } catch {
            XCTAssertEqual(error as? PlannerError, .wallpaperImport)
        }
        let after = try await store.load()
        XCTAssertEqual(before, after)
    }

    func testInvalidImportWithNoWallpaperCreatesNothing() async throws {
        do {
            try await store.saveImportedImage(Data("garbage".utf8))
            XCTFail("Expected import failure")
        } catch {
            XCTAssertEqual(error as? PlannerError, .wallpaperImport)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testRemoveDeletesImmediatelyAndIsIdempotent() async throws {
        try await store.saveImportedImage(try ImageFixtures.png(width: 120, height: 80))
        try await store.remove()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let loaded = try await store.load()
        XCTAssertNil(loaded)
        try await store.remove()
    }

    func testCorruptStoredFileLoadsAsDataForTheCallerToRecover() async throws {
        try FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
        try Data("corrupt".utf8).write(to: fileURL)
        let loaded = try await store.load()
        XCTAssertEqual(loaded, Data("corrupt".utf8))
        // The view model removes it silently after a decode failure; the store simply deletes on request.
        try await store.remove()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testStorageFailureMapsToWallpaperStorage() async throws {
        // A regular file where the Wallpaper directory should be makes directory creation fail.
        try Data("blocker".utf8).write(to: wallpaperDirectory)
        do {
            try await store.saveImportedImage(try ImageFixtures.png(width: 10, height: 10))
            XCTFail("Expected storage failure")
        } catch {
            XCTAssertEqual(error as? PlannerError, .wallpaperStorage)
        }
    }
}
