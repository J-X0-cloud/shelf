import Foundation

/// A saved arrangement of shelves: one per client, project or mode of work.
struct Space: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var shelves: [Shelf]
    /// Focus modes that bring this Space forward when they turn on.
    var focusModes: [String]

    init(id: UUID = UUID(), name: String, colorHex: String, shelves: [Shelf] = [], focusModes: [String] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.shelves = shelves
        self.focusModes = focusModes
    }

    var itemCount: Int { shelves.reduce(0) { $0 + $1.items.count } }

    var shelfCountDescription: String {
        shelves.count == 1 ? "1 shelf" : "\(shelves.count) shelves"
    }

    func shelf(id: Shelf.ID) -> Shelf? {
        shelves.first { $0.id == id }
    }

    func shelfIndex(id: Shelf.ID) -> Int? {
        shelves.firstIndex { $0.id == id }
    }
}
