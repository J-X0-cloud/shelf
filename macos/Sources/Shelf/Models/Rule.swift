import Foundation

/// "When a file in <source> <condition> → put it on <shelf>."
struct Rule: Identifiable, Codable, Hashable {
    enum Source: Codable, Hashable {
        case downloads
        case desktop
        case folder(URL)
        /// Items already sitting on any shelf (used for archiving).
        case anyShelf

        var displayName: String {
            switch self {
            case .downloads: "Downloads"
            case .desktop: "Desktop"
            case let .folder(url): url.lastPathComponent
            case .anyShelf: "Any shelf"
            }
        }

        /// The folder to watch, if the source is a folder on disk.
        func directory(fileManager: FileManager = .default) -> URL? {
            switch self {
            case .downloads: fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            case .desktop: fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
            case let .folder(url): url
            case .anyShelf: nil
            }
        }
    }

    enum Condition: Codable, Hashable {
        case extensionIs(String)
        case nameContains(String)
        case isScreenshot
        case untouched(days: Int)

        var displayText: String {
            switch self {
            case let .extensionIs(ext): "name ends with .\(ext)"
            case let .nameContains(text): "name contains \(text)"
            case .isScreenshot: "is a screenshot"
            case let .untouched(days): "untouched for \(days) days"
            }
        }
    }

    var id: UUID
    var isEnabled: Bool
    var source: Source
    var condition: Condition
    var destinationShelfID: Shelf.ID
    /// The Space the rule belongs to; `nil` means a global rule that always runs.
    var spaceID: Space.ID?

    init(
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
}
