import Foundation

/// A reference to something on a shelf. Shelves never move or copy the original;
/// they hold the URL plus a bookmark so the item survives renames and moves.
public struct ShelfItem: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case file
        case folder
        case app
        case link
    }

    public var id: UUID
    public var kind: Kind
    public var name: String
    public var url: URL
    /// Bookmark data resolved at launch so the item follows the file if it moves.
    public var bookmark: Data?
    public var addedAt: Date
    public var lastOpenedAt: Date?

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        kind: Kind? = nil,
        bookmark: Data? = nil,
        addedAt: Date = Date(),
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.kind = kind ?? ShelfItem.inferKind(for: url)
        self.name = name ?? ShelfItem.displayName(for: url)
        self.bookmark = bookmark
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
    }

    public static func inferKind(for url: URL) -> Kind {
        guard url.isFileURL else { return .link }
        if url.pathExtension.lowercased() == "app" { return .app }
        return url.hasDirectoryPath ? .folder : .file
    }

    public static func displayName(for url: URL) -> String {
        guard url.isFileURL else { return url.host ?? url.absoluteString }
        let name = url.lastPathComponent
        return url.pathExtension.lowercased() == "app" ? String(name.dropLast(4)) : name
    }

    /// The last time the item was used, falling back to when it was added.
    public var lastUsed: Date { lastOpenedAt ?? addedAt }

    /// Short uppercase badge shown on document tiles, e.g. "PDF" or "DOC". `nil` for folders, apps and links.
    public var badge: String? {
        guard kind == .file else { return nil }
        let ext = url.pathExtension
        guard !ext.isEmpty else { return nil }
        return String(ext.uppercased().prefix(3))
    }

    /// Whether two items point at the same thing, comparing file URLs by their standardized path.
    public func refersToSameTarget(as url: URL) -> Bool {
        ShelfItem.sameTarget(self.url, url)
    }

    static func sameTarget(_ lhs: URL, _ rhs: URL) -> Bool {
        if lhs.isFileURL, rhs.isFileURL {
            return lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
        }
        return lhs.absoluteString == rhs.absoluteString
    }
}
