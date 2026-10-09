import Foundation

/// A saved arrangement of shelves: one per client, project or mode of work.
public struct Space: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var shelves: [Shelf]
    /// Focus modes that bring this Space forward when they turn on.
    public var focusModes: [String]

    public init(id: UUID = UUID(), name: String, colorHex: String, shelves: [Shelf] = [], focusModes: [String] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.shelves = shelves
        self.focusModes = focusModes
    }

    public var itemCount: Int { shelves.reduce(0) { $0 + $1.items.count } }

    public var shelfCountDescription: String {
        shelves.count == 1 ? "1 shelf" : "\(shelves.count) shelves"
    }

    /// Every item in the Space, shelf by shelf. This is what the Dock stack mirrors.
    public var allItems: [ShelfItem] { shelves.flatMap(\.items) }

    public func shelf(id: Shelf.ID) -> Shelf? {
        shelves.first { $0.id == id }
    }

    public func shelfIndex(id: Shelf.ID) -> Int? {
        shelves.firstIndex { $0.id == id }
    }

    /// The shelf in this Space that already holds `url`, if any.
    public func shelf(holding url: URL) -> Shelf? {
        shelves.first { $0.contains(url) }
    }

    /// Whether the Space should come forward for a Focus mode, compared case-insensitively.
    public func follows(focusMode: String) -> Bool {
        focusModes.contains { $0.caseInsensitiveCompare(focusMode) == .orderedSame }
    }
}
