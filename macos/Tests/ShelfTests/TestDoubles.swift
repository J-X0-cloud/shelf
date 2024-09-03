import AppKit
@testable import Shelf

final class InMemoryPersistence: LayoutPersisting {
    var stored: ShelfLayout?
    private(set) var saveCount = 0

    init(_ layout: ShelfLayout? = nil) {
        stored = layout
    }

    func load() throws -> ShelfLayout? { stored }

    func save(_ layout: ShelfLayout) throws {
        stored = layout
        saveCount += 1
    }
}

final class MockDockService: DockServicing {
    var isAccessibilityTrusted = true
    var isFrontmostAppFullScreen = false
    private(set) var syncedStacks: [[ShelfItem]] = []
    private(set) var openedItems: [ShelfItem] = []

    func requestAccessibilityAccess() {}

    func syncDockStack(with items: [ShelfItem]) throws {
        syncedStacks.append(items)
    }

    func open(_ item: ShelfItem) {
        openedItems.append(item)
    }

    func revealInFinder(_ items: [ShelfItem]) {}

    func icon(for item: ShelfItem) -> NSImage { NSImage() }
}

enum Fixtures {
    static let inbox = Shelf(name: "Inbox", colorHex: "#E4572E")
    static let paperwork = Shelf(name: "Paperwork", colorHex: "#E9B44C")
    static let brand = Shelf(name: "Brand", colorHex: "#5E9C7E")

    static let studio = Space(name: "Studio", colorHex: "#E4572E", shelves: [inbox])
    static let harbor = Space(name: "Harbor Coffee rebrand", colorHex: "#5E9C7E", shelves: [brand])
    static let admin = Space(name: "Admin & invoices", colorHex: "#E9B44C", shelves: [paperwork])

    static func layout(rules: [Rule] = []) -> ShelfLayout {
        ShelfLayout(spaces: [studio, harbor, admin], rules: rules, activeSpaceID: studio.id)
    }

    static func file(_ name: String, in folder: String = "/Users/test/Downloads") -> URL {
        URL(fileURLWithPath: folder).appendingPathComponent(name)
    }
}
