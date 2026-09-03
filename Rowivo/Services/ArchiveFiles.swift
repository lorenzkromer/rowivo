import Foundation

struct ExportReceipt: Sendable {
    var date: Date
    var folderName: String
    var refreshedBookmark: Data?
}

/// File-provider coordination runs away from the main actor. A completed local write
/// means handed to the provider, not proof that a cloud server has received the data.
actor ArchiveFiles {
    private let temporaryDirectory: URL

    init(temporaryDirectory: URL = FileManager.default.temporaryDirectory) {
        self.temporaryDirectory = temporaryDirectory
    }

    func rememberFolder(_ url: URL) throws -> CloudExportSettings {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
        guard values.isDirectory == true else { throw StorageError.inaccessibleFolder }
        let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        return .init(bookmark: bookmark, folderName: values.name ?? url.lastPathComponent)
    }

    func export(_ archive: TrainingArchive, bookmark: Data) throws -> ExportReceipt {
        var stale = false
        let root: URL
        do { root = try URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale) }
        catch { throw StorageError.inaccessibleFolder }
        let access = root.startAccessingSecurityScopedResource()
        defer { if access { root.stopAccessingSecurityScopedResource() } }
        let refreshed = stale ? try root.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) : nil
        let files = try archive.exportFiles()
        let name = Self.snapshotName(date: archive.createdAt)
        var coordinationError: NSError?
        var writeError: (any Error)?
        NSFileCoordinator().coordinate(writingItemAt: root, options: .forMerging, error: &coordinationError) { coordinatedRoot in
            let destination = coordinatedRoot.appendingPathComponent(name, isDirectory: true)
            do { try Self.write(files, to: destination) }
            catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }
        return .init(date: Date(), folderName: name, refreshedBookmark: refreshed)
    }

    func prepareExport(_ archive: TrainingArchive) throws -> [URL] {
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let destination = temporaryDirectory.appendingPathComponent(Self.snapshotName(date: archive.createdAt), isDirectory: true)
        let files = try archive.exportFiles()
        try Self.write(files, to: destination)
        return files.keys.sorted().map { destination.appendingPathComponent($0) }
    }

    func removePreparedExport(_ urls: [URL]) {
        guard let root = urls.first?.deletingLastPathComponent(), root.lastPathComponent.hasPrefix("Rowivo-"),
              root.deletingLastPathComponent().standardizedFileURL == temporaryDirectory.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: root)
    }

    /// Only app-private recovery files and staging folders, never the user's export destination.
    func deleteLocalCopies(recoveryDirectory: URL) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: recoveryDirectory.path) { try manager.removeItem(at: recoveryDirectory) }
        if manager.fileExists(atPath: temporaryDirectory.path) {
            let folders = try manager.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
            for folder in folders where folder.lastPathComponent.hasPrefix("Rowivo-") {
                // Snapshot names end in a UUID. Leave unrelated temporary files alone.
                guard UUID(uuidString: String(folder.lastPathComponent.suffix(36))) != nil else { continue }
                try manager.removeItem(at: folder)
            }
        }
    }

    func readBackup(_ url: URL) throws -> TrainingArchive {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var readResult: Result<Data, any Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            readResult = Result {
                let values = try coordinatedURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile == true else { throw StorageError.invalidBackup }
                guard let size = values.fileSize, size <= 64 * 1024 * 1024 else { throw StorageError.tooLarge }
                return try Data(contentsOf: coordinatedURL)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let readResult else { throw StorageError.invalidBackup }
        return try TrainingArchive.decode(readResult.get())
    }

    func saveRecovery(_ archive: TrainingArchive, directory: URL) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".rowivo"
        try archive.encoded().write(to: directory.appendingPathComponent(name), options: .atomic)
        return name
    }

    private static func snapshotName(date: Date) -> String {
        let stamp = ISO8601DateFormatter().string(from: date).replacingOccurrences(of: ":", with: "-")
        return "Rowivo-" + stamp + "-" + UUID().uuidString.lowercased()
    }

    private static func write(_ files: [String: Data], to directory: URL) throws {
        // A unique destination avoids overwriting earlier backups or another phone's export.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        do {
            for name in files.keys.sorted() {
                try files[name]!.write(to: directory.appendingPathComponent(name), options: .atomic)
            }
            // Consumers can use this marker to distinguish complete file sets from interrupted writes.
            let marker = try JSONSerialization.data(withJSONObject: ["format_version": TrainingArchive.currentVersion, "files": files.keys.sorted()], options: .sortedKeys)
            try marker.write(to: directory.appendingPathComponent("complete.json"), options: .atomic)
        } catch {
            // Only our freshly created, unique snapshot is removed; older exports are untouched.
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
}
