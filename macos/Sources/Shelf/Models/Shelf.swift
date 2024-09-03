import Foundation

/// A floating panel of items.
struct Shelf: Identifiable, Codable, Hashable {
    enum Placement: String, Codable, CaseIterable {
        case floating
        case leading
        case trailing
        case top
        case bottom
    }

    var id: UUID
    var name: String
    var colorHex: String
    var items: [ShelfItem]
    var placement: Placement
    /// Slide out of view until the pointer reaches the pinned edge.
    var autoHide: Bool
    /// `CGDirectDisplayID`'s UUID string for the display the shelf lives on.
    var displayUUID: String?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        items: [ShelfItem] = [],
        placement: Placement = .floating,
        autoHide: Bool = false,
        displayUUID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.items = items
        self.placement = placement
        self.autoHide = autoHide
        self.displayUUID = displayUUID
    }

    func contains(_ url: URL) -> Bool {
        items.contains { $0.url.standardizedFileURL == url.standardizedFileURL }
    }

    /// Adds the item unless the same URL is already on the shelf. Returns whether it was added.
    @discardableResult
    mutating func add(_ item: ShelfItem) -> Bool {
        guard !contains(item.url) else { return false }
        items.append(item)
        return true
    }

    mutating func removeItem(id: ShelfItem.ID) {
        items.removeAll { $0.id == id }
    }
}
