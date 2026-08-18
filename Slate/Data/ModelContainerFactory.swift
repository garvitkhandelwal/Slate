import Foundation
import SwiftData

/// Owns schema configuration and the explicit local store locations. No CloudKit database is ever configured.
enum ModelContainerFactory {
    private static let storeName = "Planner.store"

    /// Production store under `Application Support/Slate/Planner.store`, excluded from device backup.
    static func production(fileManager: FileManager = .default) throws -> ModelContainer {
        let base = try slateSupportDirectory(fileManager: fileManager)
        let container = try container(storedAt: base.appending(path: storeName))
        try excludeFromBackup(base)
        return container
    }

    /// In-memory store for unit and integration tests.
    static func inMemory() throws -> ModelContainer {
        try ModelContainer(for: PlannerTask.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// Isolated UI-test store under `Application Support/Slate/UITests`, optionally wiped first.
    static func uiTesting(reset: Bool, fileManager: FileManager = .default) throws -> ModelContainer {
        let directory = try slateSupportDirectory(fileManager: fileManager).appending(path: "UITests", directoryHint: .isDirectory)
        if reset, fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try excludeFromBackup(directory)
        return try container(storedAt: directory.appending(path: storeName))
    }

    /// `Application Support/Slate`, created on demand and excluded from backup.
    static func slateSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        let root = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let slate = root.appending(path: "Slate", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: slate, withIntermediateDirectories: true)
        try excludeFromBackup(slate)
        return slate
    }

    static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    private static func container(storedAt url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: PlannerTask.self, configurations: configuration)
    }
}
