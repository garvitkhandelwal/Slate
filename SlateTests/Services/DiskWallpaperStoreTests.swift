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
    private func fileURL(_ slot: Int) -> URL { wallpaperDirectory.appending(path: "wallpaper-\(slot + 1).heic") }
    private func names() throws -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: wallpaperDirectory.path))?.sorted() ?? []
    }

    private func isExcludedFromBackup(_ url: URL) throws -> Bool {
        try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup ?? false
    }

    func testLoadAllIsEmptyWhenNothingStored() async throws {
        let loaded = try await store.loadAll()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSaveWritesSlotFileExcludedFromBackupWithoutLeftovers() async throws {
        try await store.saveImportedImage(try ImageFixtures.png(width: 120, height: 80), slot: 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL(0).path))
        XCTAssertEqual(store.fileURL(slot: 0), fileURL(0))
        XCTAssertTrue(try isExcludedFromBackup(wallpaperDirectory))
        XCTAssertTrue(try isExcludedFromBackup(fileURL(0)))
        XCTAssertEqual(try names(), ["wallpaper-1.heic"], "Atomic writes leave no temporary siblings")
        let loaded = try await store.loadAll()
        XCTAssertEqual(loaded, [try Data(contentsOf: fileURL(0))])
    }

    func testThreeSlotsLoadInOrderAndReplaceInPlace() async throws {
        try await store.saveImportedImage(try ImageFixtures.png(width: 20, height: 20, pattern: .black), slot: 0)
        try await store.saveImportedImage(try ImageFixtures.png(width: 20, height: 20, pattern: .white), slot: 1)
        try await store.saveImportedImage(try ImageFixtures.png(width: 20, height: 20, pattern: .checkerboard), slot: 2)
        XCTAssertEqual(try names(), ["wallpaper-1.heic", "wallpaper-2.heic", "wallpaper-3.heic"])
        let before = try await store.loadAll()
        XCTAssertEqual(before.count, 3)
        try await store.saveImportedImage(try ImageFixtures.png(width: 40, height: 40, pattern: .white), slot: 1)
        let after = try await store.loadAll()
        XCTAssertEqual(after.count, 3)
        XCTAssertEqual(after[0], before[0])
        XCTAssertNotEqual(after[1], before[1], "The replaced slot changes")
        XCTAssertEqual(after[2], before[2])
    }

    func testSlotOutOfRangeIsRejected() async throws {
        do {
            try await store.saveImportedImage(try ImageFixtures.png(width: 10, height: 10), slot: WallpaperSlots.count)
            XCTFail("Expected storage failure")
        } catch {
            XCTAssertEqual(error as? PlannerError, .wallpaperStorage)
        }
    }

    func testInvalidImportLeavesExistingWallpaperUntouched() async throws {
        try await store.saveImportedImage(try ImageFixtures.png(width: 120, height: 80), slot: 0)
        let before = try await store.loadAll()
        do {
            try await store.saveImportedImage(Data("garbage".utf8), slot: 0)
            XCTFail("Expected import failure")
        } catch {
            XCTAssertEqual(error as? PlannerError, .wallpaperImport)
        }
        let after = try await store.loadAll()
        XCTAssertEqual(before, after)
    }

    func testInvalidImportWithNoWallpaperCreatesNothing() async throws {
        do {
            try await store.saveImportedImage(Data("garbage".utf8), slot: 0)
            XCTFail("Expected import failure")
        } catch {
            XCTAssertEqual(error as? PlannerError, .wallpaperImport)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL(0).path))
    }

    func testRemoveDeletesImmediatelyCompactsAndIsIdempotent() async throws {
        try await store.saveImportedImage(try ImageFixtures.png(width: 20, height: 20, pattern: .black), slot: 0)
        try await store.saveImportedImage(try ImageFixtures.png(width: 20, height: 20, pattern: .white), slot: 1)
        try await store.saveImportedImage(try ImageFixtures.png(width: 20, height: 20, pattern: .checkerboard), slot: 2)
        let original = try await store.loadAll()
        try await store.remove(slot: 0)
        XCTAssertEqual(try names(), ["wallpaper-1.heic", "wallpaper-2.heic"], "Later slots shift down")
        let remaining = try await store.loadAll()
        XCTAssertEqual(remaining, [original[1], original[2]])
        try await store.remove(slot: 1)
        try await store.remove(slot: 1)
        let last = try await store.loadAll()
        XCTAssertEqual(last, [original[1]])
    }

    func testLegacySingleFileIsAdoptedAsFirstSlot() async throws {
        try FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
        let legacy = try ImageFixtures.png(width: 30, height: 30)
        try legacy.write(to: store.legacyFileURL)
        let loaded = try await store.loadAll()
        XCTAssertEqual(loaded, [legacy])
        XCTAssertEqual(try names(), ["wallpaper-1.heic"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.legacyFileURL.path))
    }

    func testCorruptStoredFileLoadsAsDataForTheCallerToRecover() async throws {
        try FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
        try Data("corrupt".utf8).write(to: fileURL(0))
        let loaded = try await store.loadAll()
        XCTAssertEqual(loaded, [Data("corrupt".utf8)])
        // The view model removes it silently after a decode failure; the store simply deletes on request.
        try await store.remove(slot: 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL(0).path))
    }

    func testStorageFailureMapsToWallpaperStorage() async throws {
        // A regular file where the Wallpaper directory should be makes directory creation fail.
        try Data("blocker".utf8).write(to: wallpaperDirectory)
        do {
            try await store.saveImportedImage(try ImageFixtures.png(width: 10, height: 10), slot: 0)
            XCTFail("Expected storage failure")
        } catch {
            XCTAssertEqual(error as? PlannerError, .wallpaperStorage)
        }
    }
}
