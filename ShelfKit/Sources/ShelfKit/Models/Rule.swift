import Foundation

/// "When a file in <source> <condition> → put it on <shelf>."
public struct Rule: Identifiable, Codable, Hashable, Sendable {
    public enum Source: Codable, Hashable, Sendable {
        case downloads
        case desktop
        case folder(URL)
        /// Items already sitting on any shelf (used for archiving).
        case anyShelf

        public var displayName: String {
            switch self {
            case .downloads: "Downloads"
            case .desktop: "Desktop"
            case let .folder(url): url.lastPathComponent
            case .anyShelf: "Any shelf"
            }
        }

        /// The folder to watch, if the source is a folder on disk.
        public func directory(in folders: KnownFolders = .current) -> URL? {
            switch self {
            case .downloads: folders.downloads
            case .desktop: folders.desktop
            case let .folder(url): url
            case .anyShelf: nil
            }
        }

        /// Whether a rule with this source applies to a file reported from `other`.
        public func matches(_ other: Source) -> Bool {
            switch (self, other) {
            case let (.folder(a), .folder(b)):
                return a.standardizedFileURL.path == b.standardizedFileURL.path
            default:
                return self == other
            }
        }
    }

    public enum Condition: Codable, Hashable, Sendable {
        case extensionIs(String)
        case nameContains(String)
        case isScreenshot
        case untouched(days: Int)

        public var displayText: String {
            switch self {
            case let .extensionIs(ext): "name ends with .\(Condition.normalizedExtension(ext))"
            case let .nameContains(text): "name contains \(text)"
            case .isScreenshot: "is a screenshot"
            case let .untouched(days): days == 1 ? "untouched for 1 day" : "untouched for \(days) days"
            }
        }

        /// Whether the condition can ever match. An empty extension or search text would catch
        /// everything, which is never what someone typing a rule means.
        public var isValid: Bool {
            switch self {
            case let .extensionIs(ext): !Condition.normalizedExtension(ext).isEmpty
            case let .nameContains(text): !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .isScreenshot: true
            case let .untouched(days): days > 0
            }
        }

        /// "  .PDF " → "pdf".
        public static func normalizedExtension(_ ext: String) -> String {
            ext.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .lowercased()
        }
    }

    public var id: UUID
    public var isEnabled: Bool
    public var source: Source
    public var condition: Condition
    public var destinationShelfID: Shelf.ID
    /// The Space the rule belongs to; `nil` means a global rule that always runs.
    public var spaceID: Space.ID?

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        source: Source,
        condition: Condition,
        destinationShelfID: Shelf.ID,
        spaceID: Space.ID? = nil
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.source = source
        self.condition = condition
        self.destinationShelfID = destinationShelfID
        self.spaceID = spaceID
    }

    public var isGlobal: Bool { spaceID == nil }

    /// The rule in plain words, e.g. "When a file in Downloads name ends with .pdf".
    public var summary: String {
        "When a file in \(source.displayName) \(condition.displayText)"
    }
}

/// The user folders Rules can watch. Injectable so tests never touch a real home folder.
public struct KnownFolders: Hashable, Sendable {
    public var downloads: URL?
    public var desktop: URL?

    public init(downloads: URL?, desktop: URL?) {
        self.downloads = downloads
        self.desktop = desktop
    }

    public static var current: KnownFolders {
        let fileManager = FileManager.default
        return KnownFolders(
            downloads: fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            desktop: fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
        )
    }
}
