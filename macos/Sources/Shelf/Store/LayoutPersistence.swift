import Foundation

protocol LayoutPersisting {
    func load() throws -> ShelfLayout?
    func save(_ layout: ShelfLayout) throws
}

/// Stores the layout as a small JSON file in Application Support. That file is the whole of
/// Shelf's data; nothing leaves the Mac.
struct FileLayoutPersistence: LayoutPersisting {
    let fileURL: URL

    init(fileURL: URL = FileLayoutPersistence.defaultURL) {
        self.fileURL = fileURL
    }

    static var defaultURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Shelf/Layout.json")
    }

    func load() throws -> ShelfLayout? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try LayoutCoder.decoder.decode(ShelfLayout.self, from: data)
    }

    func save(_ layout: ShelfLayout) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try LayoutCoder.encoder.encode(layout)
        try data.write(to: fileURL, options: .atomic)
    }
}

enum LayoutCoder {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
