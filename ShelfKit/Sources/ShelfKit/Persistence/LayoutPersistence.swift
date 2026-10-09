import Foundation

public protocol LayoutPersisting {
    func load() throws -> ShelfLayout?
    func save(_ layout: ShelfLayout) throws
}

/// Stores the layout as a small JSON file in Application Support. That file is the whole of
/// Shelf's data; nothing leaves the Mac.
public struct FileLayoutPersistence: LayoutPersisting {
    public let fileURL: URL

    public init(fileURL: URL = FileLayoutPersistence.defaultURL) {
        self.fileURL = fileURL
    }

    public static var defaultURL: URL {
        let fileManager = FileManager.default
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("Shelf/Layout.json")
    }

    public func load() throws -> ShelfLayout? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try LayoutCoder.decode(Data(contentsOf: fileURL))
    }

    /// Writes atomically, keeping the previous file as `Layout.json.bak` so one bad write
    /// can never cost someone their arrangement.
    public func save(_ layout: ShelfLayout) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: fileURL.path) {
            let backup = backupURL
            try? fileManager.removeItem(at: backup)
            try? fileManager.copyItem(at: fileURL, to: backup)
        }
        try LayoutCoder.encode(layout).write(to: fileURL, options: .atomic)
    }

    public var backupURL: URL {
        fileURL.appendingPathExtension("bak")
    }

    /// Loads the backup written before the last save, used when the main file can't be read.
    public func loadBackup() throws -> ShelfLayout? {
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return nil }
        return try LayoutCoder.decode(Data(contentsOf: backupURL))
    }
}

/// Keeps the layout in memory. Used by previews and tests.
public final class InMemoryLayoutPersistence: LayoutPersisting {
    public var stored: ShelfLayout?
    public private(set) var saveCount = 0
    public var failNextSave = false

    public init(_ layout: ShelfLayout? = nil) {
        stored = layout
    }

    public func load() throws -> ShelfLayout? { stored }

    public func save(_ layout: ShelfLayout) throws {
        if failNextSave {
            failNextSave = false
            throw CocoaError(.fileWriteUnknown)
        }
        stored = layout
        saveCount += 1
    }
}

/// The one JSON format Shelf reads and writes, for both `Layout.json` and `.shelfspace` exports.
public enum LayoutCoder {
    public static let fileExtension = "shelfspace"

    public static func encode(_ layout: ShelfLayout) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(layout)
    }

    public static func decode(_ data: Data) throws -> ShelfLayout {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var layout = try decoder.decode(ShelfLayout.self, from: data)
        layout.normalize()
        return layout
    }

    /// A copy for sharing: bookmarks and usage dates are personal to one Mac, so exports drop them.
    public static func exportData(for layout: ShelfLayout) throws -> Data {
        var shared = layout
        for spaceIndex in shared.spaces.indices {
            for shelfIndex in shared.spaces[spaceIndex].shelves.indices {
                for itemIndex in shared.spaces[spaceIndex].shelves[shelfIndex].items.indices {
                    shared.spaces[spaceIndex].shelves[shelfIndex].items[itemIndex].bookmark = nil
                    shared.spaces[spaceIndex].shelves[shelfIndex].items[itemIndex].lastOpenedAt = nil
                }
                shared.spaces[spaceIndex].shelves[shelfIndex].displayUUID = nil
            }
        }
        return try encode(shared)
    }
}
