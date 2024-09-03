import Foundation

/// Everything Shelf persists. Also the payload of an exported `.shelfspace` file.
struct ShelfLayout: Codable, Equatable {
    static let currentVersion = 2

    var version: Int
    var spaces: [Space]
    var rules: [Rule]
    var activeSpaceID: Space.ID?
    var runsRulesAutomatically: Bool

    init(
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

    func spaceIndex(id: Space.ID) -> Int? {
        spaces.firstIndex { $0.id == id }
    }

    /// Finds the Space and shelf indices that hold a shelf.
    func location(ofShelf id: Shelf.ID) -> (space: Int, shelf: Int)? {
        for (spaceIndex, space) in spaces.enumerated() {
            if let shelfIndex = space.shelfIndex(id: id) {
                return (spaceIndex, shelfIndex)
            }
        }
        return nil
    }
}

extension ShelfLayout {
    /// First-launch layout, so a new install opens to something useful rather than an empty menu.
    static func starter() -> ShelfLayout {
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
