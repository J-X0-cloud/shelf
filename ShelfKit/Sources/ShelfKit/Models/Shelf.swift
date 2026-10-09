import Foundation

/// A floating panel of items.
public struct Shelf: Identifiable, Codable, Hashable, Sendable {
    public enum Placement: String, Codable, CaseIterable, Sendable {
        case floating
        case leading
        case trailing
        case top
        case bottom

        /// Whether the shelf hugs a screen edge (and so can slide out of view when `autoHide` is on).
        public var isPinned: Bool { self != .floating }
    }

    public enum SortOrder: String, Codable, CaseIterable, Sendable {
        /// The order the user arranged by hand.
        case manual
        case name
        case dateAdded
        case lastUsed
        case kind
    }

    public var id: UUID
    public var name: String
    public var colorHex: String
    public var items: [ShelfItem]
    public var placement: Placement
    /// Slide out of view until the pointer reaches the pinned edge.
    public var autoHide: Bool
    /// `CGDirectDisplayID`'s UUID string for the display the shelf lives on.
    public var displayUUID: String?
    public var sortOrder: SortOrder

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        items: [ShelfItem] = [],
        placement: Placement = .floating,
        autoHide: Bool = false,
        displayUUID: String? = nil,
        sortOrder: SortOrder = .manual
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.items = items
        self.placement = placement
        self.autoHide = autoHide
        self.displayUUID = displayUUID
        self.sortOrder = sortOrder
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, colorHex, items, placement, autoHide, displayUUID, sortOrder
    }

    /// Layouts written before sort orders existed decode with `.manual`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        items = try container.decodeIfPresent([ShelfItem].self, forKey: .items) ?? []
        placement = try container.decodeIfPresent(Placement.self, forKey: .placement) ?? .floating
        autoHide = try container.decodeIfPresent(Bool.self, forKey: .autoHide) ?? false
        displayUUID = try container.decodeIfPresent(String.self, forKey: .displayUUID)
        sortOrder = try container.decodeIfPresent(SortOrder.self, forKey: .sortOrder) ?? .manual
    }

    public func contains(_ url: URL) -> Bool {
        items.contains { $0.refersToSameTarget(as: url) }
    }

    public func index(of url: URL) -> Int? {
        items.firstIndex { $0.refersToSameTarget(as: url) }
    }

    public func itemIndex(id: ShelfItem.ID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    /// Adds the item unless the same URL is already on the shelf. Returns whether it was added.
    @discardableResult
    public mutating func add(_ item: ShelfItem) -> Bool {
        insert(item, at: items.endIndex)
    }

    /// Inserts the item at `index` (clamped to the shelf) unless the URL is already on the shelf.
    @discardableResult
    public mutating func insert(_ item: ShelfItem, at index: Int) -> Bool {
        guard !contains(item.url) else { return false }
        items.insert(item, at: min(max(index, 0), items.endIndex))
        return true
    }

    @discardableResult
    public mutating func removeItem(id: ShelfItem.ID) -> ShelfItem? {
        guard let index = itemIndex(id: id) else { return nil }
        return items.remove(at: index)
    }

    /// Moves the items at `offsets` so they land before the item that was at `destination`,
    /// matching the semantics of SwiftUI's `onMove`. Sorting switches back to manual.
    public mutating func moveItems(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard offsets.contains(where: { items.indices.contains($0) }) else { return }
        items.move(fromOffsets: offsets, toOffset: destination)
        sortOrder = .manual
    }

    /// The items in the order the shelf displays them.
    public var sortedItems: [ShelfItem] {
        switch sortOrder {
        case .manual:
            return items
        case .name:
            return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .dateAdded:
            return items.sorted { $0.addedAt > $1.addedAt }
        case .lastUsed:
            return items.sorted { $0.lastUsed > $1.lastUsed }
        case .kind:
            return items.sorted { lhs, rhs in
                guard lhs.kind == rhs.kind else {
                    return Shelf.kindRank(lhs.kind) < Shelf.kindRank(rhs.kind)
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    public var itemCountDescription: String {
        items.count == 1 ? "1 item" : "\(items.count) items"
    }

    private static func kindRank(_ kind: ShelfItem.Kind) -> Int {
        switch kind {
        case .folder: 0
        case .app: 1
        case .file: 2
        case .link: 3
        }
    }
}
