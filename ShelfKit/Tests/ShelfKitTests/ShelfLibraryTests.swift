import XCTest
@testable import ShelfKit

final class ShelfLibraryTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_790_000_000)

    private func library(rules: [Rule] = []) -> ShelfLibrary {
        ShelfLibrary(layout: Fixtures.layout(rules: rules))
    }

    // MARK: Spaces

    func testShortcutsSwitchSpacesAndIgnoreOutOfRange() {
        var library = library()
        XCTAssertTrue(library.switchToSpace(shortcut: 2))
        XCTAssertEqual(library.activeSpace.id, Fixtures.harbor.id)
        XCTAssertFalse(library.switchToSpace(shortcut: 2), "already active")
        XCTAssertFalse(library.switchToSpace(shortcut: 9))
        XCTAssertFalse(library.switchToSpace(shortcut: 0))
        XCTAssertEqual(library.shortcutLabel(forSpace: Fixtures.admin.id), "⌘3")
    }

    func testFocusModesBringTheirSpaceForward() {
        var library = library()
        library.switchToSpace(id: Fixtures.admin.id)
        XCTAssertTrue(library.focusModeDidActivate("work"))
        XCTAssertEqual(library.activeSpace.id, Fixtures.studio.id)
        XCTAssertFalse(library.focusModeDidActivate("Sleep"))
    }

    func testAddingASpaceGivesItAnInboxAndTheNextColour() throws {
        var library = library()
        let id = try library.addSpace(named: "  Northwind pitch ")
        let space = try XCTUnwrap(library.spaces.first { $0.id == id })
        XCTAssertEqual(space.name, "Northwind pitch")
        XCTAssertEqual(space.colorHex, ShelfLibrary.palette[3])
        XCTAssertEqual(space.shelves.map(\.name), ["Inbox"])
        XCTAssertThrowsError(try library.addSpace(named: "   ")) { XCTAssertEqual($0 as? LibraryError, .emptyName) }
    }

    func testDeletingASpaceRemovesItsRulesAndMovesActiveSpace() throws {
        let scoped = Rule(source: .downloads, condition: .extensionIs("ai"), destinationShelfID: Fixtures.inbox.id, spaceID: Fixtures.harbor.id)
        let intoHarbor = Rule(source: .downloads, condition: .nameContains("harbor"), destinationShelfID: Fixtures.brand.id)
        let unrelated = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        var library = library(rules: [scoped, intoHarbor, unrelated])
        library.switchToSpace(id: Fixtures.harbor.id)

        try library.deleteSpace(Fixtures.harbor.id)

        XCTAssertEqual(library.spaces.map(\.name), ["Studio", "Admin & invoices"])
        XCTAssertEqual(library.rules.map(\.id), [unrelated.id])
        XCTAssertEqual(library.activeSpace.id, Fixtures.admin.id)
    }

    func testTheLastSpaceCannotBeDeleted() throws {
        var library = ShelfLibrary(layout: ShelfLayout(spaces: [Fixtures.studio]))
        XCTAssertThrowsError(try library.deleteSpace(Fixtures.studio.id)) { XCTAssertEqual($0 as? LibraryError, .lastSpace) }
    }

    func testMovingSpacesChangesShortcuts() {
        var library = library()
        library.moveSpaces(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(library.spaces.map(\.name), ["Admin & invoices", "Studio", "Harbor Coffee rebrand"])
        XCTAssertEqual(library.shortcutLabel(forSpace: Fixtures.admin.id), "⌘1")
    }

    // MARK: Shelves and items

    func testAddSkipsDuplicatesAndInsertsAtIndex() throws {
        var library = library()
        let first = try library.add([Fixtures.item("a.pdf"), Fixtures.item("b.pdf")], toShelf: Fixtures.inbox.id)
        XCTAssertEqual(first.count, 2)

        let second = try library.add([Fixtures.item("c.pdf"), Fixtures.item("a.pdf"), Fixtures.item("d.pdf")], toShelf: Fixtures.inbox.id, at: 1)
        XCTAssertEqual(second.map(\.name), ["c.pdf", "d.pdf"])
        XCTAssertEqual(library.activeSpace.shelves[0].items.map(\.name), ["a.pdf", "c.pdf", "d.pdf", "b.pdf"])

        XCTAssertThrowsError(try library.add([Fixtures.item("x")], toShelf: UUID()))
    }

    func testStashCreatesAShelfWhenTheSpaceHasNone() throws {
        let empty = Space(name: "Empty", colorHex: "#8A5CD6")
        var library = ShelfLibrary(layout: ShelfLayout(spaces: [empty]))
        let added = try library.stash([Fixtures.item("Brief v3.docx", in: "/Users/test/Desktop")])
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(library.activeSpace.shelves.map(\.name), ["Stash"])
        XCTAssertEqual(library.activeSpace.shelves[0].colorHex, "#8A5CD6")
    }

    func testMovingAnItemBetweenShelvesAndSpaces() throws {
        var library = library()
        let item = Fixtures.item("logo-final.svg")
        try library.add([item], toShelf: Fixtures.inbox.id)
        try library.add([Fixtures.item("palette.ase")], toShelf: Fixtures.brand.id)

        XCTAssertTrue(try library.moveItem(item.id, fromShelf: Fixtures.inbox.id, toShelf: Fixtures.brand.id, at: 0))

        XCTAssertTrue(library.activeSpace.shelves[0].items.isEmpty)
        XCTAssertEqual(library.layout.shelf(id: Fixtures.brand.id)?.items.map(\.name), ["logo-final.svg", "palette.ase"])
        XCTAssertFalse(try library.moveItem(UUID(), fromShelf: Fixtures.inbox.id, toShelf: Fixtures.brand.id))
    }

    func testReorderingWithinAShelfUsesBeforeIndexSemantics() throws {
        var library = library()
        try library.add(["a", "b", "c", "d"].map { Fixtures.item("\($0).txt") }, toShelf: Fixtures.inbox.id)

        try library.reorderItems(onShelf: Fixtures.inbox.id, fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(library.activeSpace.shelves[0].items.map(\.name), ["b.txt", "c.txt", "a.txt", "d.txt"])

        try library.reorderItems(onShelf: Fixtures.inbox.id, fromOffsets: IndexSet([1, 3]), toOffset: 0)
        XCTAssertEqual(library.activeSpace.shelves[0].items.map(\.name), ["c.txt", "d.txt", "b.txt", "a.txt"])
    }

    func testDeletingAShelfRemovesRulesThatFiledOntoIt() throws {
        let rule = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        var library = library(rules: [rule])
        try library.deleteShelf(Fixtures.paperwork.id)
        XCTAssertTrue(library.rules.isEmpty)
        XCTAssertTrue(library.layout.orphanedRules.isEmpty)
    }

    func testUpdatingAShelfKeepsItsIdentity() throws {
        var library = library()
        try library.updateShelf(Fixtures.inbox.id) {
            $0.id = UUID()
            $0.name = " Today "
            $0.placement = .trailing
        }
        let shelf = try XCTUnwrap(library.layout.shelf(id: Fixtures.inbox.id))
        XCTAssertEqual(shelf.name, "Today")
        XCTAssertEqual(shelf.placement, .trailing)
    }

    func testSearchCoversLinksAndPutsTheActiveSpaceFirst() throws {
        var library = library()
        try library.add([Fixtures.item("palette.ase")], toShelf: Fixtures.brand.id)
        try library.add([Fixtures.item("palette-old.ase")], toShelf: Fixtures.inbox.id)
        try library.add([ShelfItem(url: URL(string: "https://fonts.example.com/specimen/palette")!)], toShelf: Fixtures.paperwork.id)

        let results = library.search("  PALETTE ")
        XCTAssertEqual(results.map(\.space.name), ["Studio", "Harbor Coffee rebrand", "Admin & invoices"])
        XCTAssertTrue(library.search("   ").isEmpty)
    }

    func testMarkOpenedRecordsTheDate() throws {
        var library = library()
        let item = Fixtures.item("Brief v3.docx")
        try library.add([item], toShelf: Fixtures.inbox.id)
        let opened = library.markOpened(item.id, onShelf: Fixtures.inbox.id, at: date)
        XCTAssertEqual(opened?.lastOpenedAt, date)
        XCTAssertEqual(opened?.lastUsed, date)
    }

    // MARK: Rules

    func testRulesAreValidatedBeforeTheyAreSaved() {
        var library = library()
        XCTAssertThrowsError(try library.addRule(Rule(source: .downloads, condition: .nameContains(""), destinationShelfID: Fixtures.inbox.id))) {
            XCTAssertEqual($0 as? LibraryError, .invalidRule)
        }
        XCTAssertThrowsError(try library.addRule(Rule(source: .downloads, condition: .isScreenshot, destinationShelfID: UUID()))) {
            XCTAssertEqual($0 as? LibraryError, .unknownShelf)
        }
        XCTAssertThrowsError(try library.addRule(Rule(source: .downloads, condition: .isScreenshot, destinationShelfID: Fixtures.inbox.id, spaceID: UUID()))) {
            XCTAssertEqual($0 as? LibraryError, .unknownSpace)
        }
        XCTAssertNoThrow(try library.addRule(Rule(source: .downloads, condition: .isScreenshot, destinationShelfID: Fixtures.inbox.id)))
    }

    func testProcessFilesAndUndoes() {
        let rule = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        var library = library(rules: [rule])
        let item = Fixtures.item("invoice-0932.pdf")

        let move = library.process(FileCandidate(url: item.url, source: .downloads), item: item, engine: RuleEngine(), at: date)
        XCTAssertEqual(move?.ruleID, rule.id)
        XCTAssertEqual(library.layout.shelf(id: Fixtures.paperwork.id)?.items.map(\.name), ["invoice-0932.pdf"])

        XCTAssertNil(library.process(FileCandidate(url: item.url, source: .downloads), item: item, engine: RuleEngine(), at: date), "already filed")

        XCTAssertFalse(library.undoLastAutomaticMove(at: date.addingTimeInterval(ShelfLibrary.undoWindow + 1)))
        XCTAssertTrue(library.undoLastAutomaticMove(at: date.addingTimeInterval(60)))
        XCTAssertEqual(library.layout.shelf(id: Fixtures.paperwork.id)?.items, [])
        XCTAssertNil(library.lastAutomaticMove)
    }

    func testSweepArchivesUntouchedItemsAndUndoPutsThemBack() throws {
        let archiveRule = Rule(source: .anyShelf, condition: .untouched(days: 30), destinationShelfID: Fixtures.archive.id)
        var library = library(rules: [archiveRule])
        let old = Fixtures.item("q1-numbers.csv", addedAt: date.addingTimeInterval(-40 * 86_400))
        let fresh = Fixtures.item("q3-numbers.csv", addedAt: date.addingTimeInterval(-2 * 86_400))
        try library.add([old, fresh], toShelf: Fixtures.inbox.id)

        let engine = RuleEngine(now: { [date] in date })
        let moves = library.sweepShelves(engine: engine, at: date)

        XCTAssertEqual(moves.map(\.item.name), ["q1-numbers.csv"])
        XCTAssertEqual(library.layout.shelf(id: Fixtures.inbox.id)?.items.map(\.name), ["q3-numbers.csv"])
        XCTAssertEqual(library.layout.shelf(id: Fixtures.archive.id)?.items.map(\.name), ["q1-numbers.csv"])
        XCTAssertTrue(library.sweepShelves(engine: engine, at: date).isEmpty, "archived items stay put")

        XCTAssertTrue(library.undoLastAutomaticMove(at: date))
        XCTAssertEqual(library.layout.shelf(id: Fixtures.inbox.id)?.items.map(\.name), ["q3-numbers.csv", "q1-numbers.csv"])
    }

    func testNothingRunsWhenAutomaticRunsAreOff() {
        let rule = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        var library = library(rules: [rule])
        library.setRunsRulesAutomatically(false)
        let item = Fixtures.item("a.pdf")
        XCTAssertNil(library.process(FileCandidate(url: item.url, source: .downloads), item: item, engine: RuleEngine(), at: date))
        XCTAssertTrue(library.sweepShelves(engine: RuleEngine(), at: date).isEmpty)
    }

    // MARK: Templates

    func testTemplatesImportWithFreshIdentifiers() {
        let template = Fixtures.layout(rules: [
            Rule(source: .downloads, condition: .nameContains("harbor"), destinationShelfID: Fixtures.brand.id, spaceID: Fixtures.harbor.id),
        ])
        var library = library()

        let first = library.addSpaces(from: template)
        let second = library.addSpaces(from: template)

        XCTAssertEqual(library.spaces.count, 9)
        XCTAssertEqual(Set(first).intersection(second), [])
        XCTAssertEqual(Set(library.spaces.map(\.id)).count, 9)
        XCTAssertEqual(library.rules.count, 2)
        XCTAssertTrue(library.layout.orphanedRules.isEmpty)
        XCTAssertTrue(library.rules.allSatisfy { rule in first.contains(rule.spaceID!) || second.contains(rule.spaceID!) })
    }

    func testShelfSortOrders() {
        let a = ShelfItem(url: Fixtures.file("b-report.pdf"), addedAt: date)
        let b = ShelfItem(url: URL(fileURLWithPath: "/Users/test/Exports", isDirectory: true), addedAt: date.addingTimeInterval(10))
        var c = ShelfItem(url: Fixtures.file("a-notes.txt"), addedAt: date.addingTimeInterval(-10))
        c.lastOpenedAt = date.addingTimeInterval(100)
        var shelf = Shelf(name: "Inbox", colorHex: "#E4572E", items: [a, b, c])

        shelf.sortOrder = .name
        XCTAssertEqual(shelf.sortedItems.map(\.name), ["a-notes.txt", "b-report.pdf", "Exports"])
        shelf.sortOrder = .dateAdded
        XCTAssertEqual(shelf.sortedItems.map(\.name), ["Exports", "b-report.pdf", "a-notes.txt"])
        shelf.sortOrder = .lastUsed
        XCTAssertEqual(shelf.sortedItems.first?.name, "a-notes.txt")
        shelf.sortOrder = .kind
        XCTAssertEqual(shelf.sortedItems.first?.name, "Exports")

        shelf.moveItems(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(shelf.sortOrder, .manual, "dragging by hand switches back to manual order")
        XCTAssertEqual(shelf.itemCountDescription, "3 items")
    }
}
