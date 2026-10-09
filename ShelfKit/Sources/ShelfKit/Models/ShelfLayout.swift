import Foundation

/// Everything Shelf persists. Also the payload of an exported `.shelfspace` file.
public struct ShelfLayout: Codable, Equatable, Sendable {
    /// Version 1 (Shelf 2.0–2.3) had global rules only and no automatic-run switch.
    /// Version 2 (Shelf 2.4) added per-Space rules and `runsRulesAutomatically`.
    public static let currentVersion = 2

    public var version: Int
    public var spaces: [Space]
    public var rules: [Rule]
    public var activeSpaceID: Space.ID?
    public var runsRulesAutomatically: Bool

    public init(
        spaces: [Space],
        rules: [Rule] = [],
        activeSpaceID: Space.ID? = nil,
        runsRulesAutomatically: Bool = true
    ) {
        version = ShelfLayout.currentVersion
        self.spaces = spaces
        self.rules = rules
        self.activeSpaceID = activeSpaceID ?? spaces.first?.id
        self.runsRulesAutomatically = runsRulesAutomatically
    }

    private enum CodingKeys: String, CodingKey {
        case version, spaces, rules, activeSpaceID, runsRulesAutomatically
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard version <= ShelfLayout.currentVersion else {
            throw LayoutError.unsupportedVersion(version)
        }
        spaces = try container.decode([Space].self, forKey: .spaces)
        rules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        activeSpaceID = try container.decodeIfPresent(Space.ID.self, forKey: .activeSpaceID)
        runsRulesAutomatically = try container.decodeIfPresent(Bool.self, forKey: .runsRulesAutomatically) ?? true
        // Everything older decodes into the current shape, so the next save writes the current version.
        self.version = ShelfLayout.currentVersion
        try validate()
    }

    /// Repairs references that can go stale after a hand-edited or partially imported file:
    /// an active Space that no longer exists, or a Space with no shelves.
    public mutating func normalize() {
        if spaces.isEmpty {
            spaces = ShelfLayout.starter().spaces
        }
        if activeSpaceID.map({ spaceIndex(id: $0) == nil }) ?? true {
            activeSpaceID = spaces.first?.id
        }
    }

    private func validate() throws {
        var shelfIDs = Set<Shelf.ID>()
        for shelf in spaces.flatMap(\.shelves) {
            guard shelfIDs.insert(shelf.id).inserted else {
                throw LayoutError.duplicateShelf(shelf.id)
            }
        }
        var spaceIDs = Set<Space.ID>()
        for space in spaces {
            guard spaceIDs.insert(space.id).inserted else {
                throw LayoutError.duplicateSpace(space.id)
            }
        }
    }

    public func spaceIndex(id: Space.ID) -> Int? {
        spaces.firstIndex { $0.id == id }
    }

    /// Finds the Space and shelf indices that hold a shelf.
    public func location(ofShelf id: Shelf.ID) -> ShelfLocation? {
        for (spaceIndex, space) in spaces.enumerated() {
            if let shelfIndex = space.shelfIndex(id: id) {
                return ShelfLocation(space: spaceIndex, shelf: shelfIndex)
            }
        }
        return nil
    }

    public func shelf(id: Shelf.ID) -> Shelf? {
        location(ofShelf: id).map { self[$0] }
    }

    /// The active Space, falling back to the first one when the stored ID is stale.
    public var activeSpace: Space? {
        activeSpaceID.flatMap { id in spaces.first { $0.id == id } } ?? spaces.first
    }

    /// Rules whose destination shelf was deleted. Settings shows these so they can be fixed or removed.
    public var orphanedRules: [Rule] {
        rules.filter { location(ofShelf: $0.destinationShelfID) == nil }
    }

    public subscript(location: ShelfLocation) -> Shelf {
        get { spaces[location.space].shelves[location.shelf] }
        set { spaces[location.space].shelves[location.shelf] = newValue }
    }
}

/// Indices of a shelf inside a layout.
public struct ShelfLocation: Hashable, Sendable {
    public var space: Int
    public var shelf: Int

    public init(space: Int, shelf: Int) {
        self.space = space
        self.shelf = shelf
    }
}

public enum LayoutError: Error, Equatable, CustomStringConvertible {
    case unsupportedVersion(Int)
    case duplicateShelf(Shelf.ID)
    case duplicateSpace(Space.ID)

    public var description: String {
        switch self {
        case let .unsupportedVersion(version):
            "This layout was saved by a newer version of Shelf (format \(version))."
        case .duplicateShelf:
            "The layout lists the same shelf twice."
        case .duplicateSpace:
            "The layout lists the same Space twice."
        }
    }
}

extension ShelfLayout {
    /// First-launch layout, so a new install opens to something useful rather than an empty menu.
    public static func starter() -> ShelfLayout {
        let inbox = Shelf(name: "Inbox", colorHex: "#E4572E", placement: .leading)
        let paperwork = Shelf(name: "Paperwork", colorHex: "#E9B44C")
        let archive = Shelf(name: "Archive", colorHex: "#7FA7D9", autoHide: true)

        let studio = Space(name: "Studio", colorHex: "#E4572E", shelves: [inbox, archive], focusModes: ["Work"])
        let admin = Space(name: "Admin & invoices", colorHex: "#E9B44C", shelves: [paperwork])

        return ShelfLayout(
            spaces: [studio, admin],
            rules: [
                Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: paperwork.id, spaceID: admin.id),
                Rule(source: .desktop, condition: .isScreenshot, destinationShelfID: inbox.id, spaceID: studio.id),
                Rule(isEnabled: false, source: .anyShelf, condition: .untouched(days: 30), destinationShelfID: archive.id),
            ],
            activeSpaceID: studio.id
        )
    }
}
