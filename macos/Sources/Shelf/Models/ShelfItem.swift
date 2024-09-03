import Foundation

/// A reference to something on a shelf. Shelves never move or copy the original;
/// they hold the URL plus a bookmark so the item survives renames and moves.
struct ShelfItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case file
        case folder
        case app
        case link
    }

    var id: UUID
    var kind: Kind
    var name: String
    var url: URL
    /// Bookmark data resolved at launch so the item follows the file if it moves.
    var bookmark: Data?
    var addedAt: Date
    var lastOpenedAt: Date?

    init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        kind: Kind? = nil,
        bookmark: Data? = nil,
        addedAt: Date = .now
    ) {
        self.id = id
        self.url = url
        self.kind = kind ?? ShelfItem.inferKind(for: url)
        self.name = name ?? ShelfItem.displayName(for: url)
        self.bookmark = bookmark
        self.addedAt = addedAt
    }

    static func inferKind(for url: URL) -> Kind {
        guard url.isFileURL else { return .link }
        if url.pathExtension == "app" { return .app }
        return url.hasDirectoryPath ? .folder : .file
    }

    static func displayName(for url: URL) -> String {
        guard url.isFileURL else { return url.host ?? url.absoluteString }
        let name = url.lastPathComponent
        return url.pathExtension == "app" ? String(name.dropLast(4)) : name
    }

    /// The last time the item was used, falling back to when it was added.
    var lastUsed: Date { lastOpenedAt ?? addedAt }
}
