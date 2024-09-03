import XCTest
@testable import Shelf

@MainActor
final class ShelfStoreTests: XCTestCase {
    private var persistence: InMemoryPersistence!
    private var dock: MockDockService!
    private var clock: Date!

    override func setUp() async throws {
        persistence = InMemoryPersistence(Fixtures.layout())
        dock = MockDockService()
        clock = ISO8601DateFormatter().date(from: "2026-09-24T09:41:00Z")!
    }

    private func makeStore(rules: [Rule] = []) -> ShelfStore {
        persistence.stored = Fixtures.layout(rules: rules)
        return ShelfStore(persistence: persistence, dock: dock, now: { [unowned self] in self.clock })
    }

    func testLoadsPersistedLayout() {
        let store = makeStore()
        XCTAssertEqual(store.spaces.map(\.name), ["Studio", "Harbor Coffee rebrand", "Admin & invoices"])
        XCTAssertEqual(store.activeSpace.id, Fixtures.studio.id)
    }

    func testFallsBackToStarterLayoutOnFirstLaunch() {
        let store = ShelfStore(persistence: InMemoryPersistence(), dock: dock)
        XCTAssertFalse(store.spaces.isEmpty)
        XCTAssertFalse(store.rules.isEmpty)
    }

    func testSwitchingByShortcutPersistsAndIgnoresOutOfRange() {
        let store = makeStore()
        store.switchToSpace(shortcut: 2)
        XCTAssertEqual(store.activeSpace.id, Fixtures.harbor.id)
        XCTAssertEqual(persistence.stored?.activeSpaceID, Fixtures.harbor.id)

        store.switchToSpace(shortcut: 9)
        XCTAssertEqual(store.activeSpace.id, Fixtures.harbor.id)
    }

    func testStashSkipsDuplicatesAndSyncsDockStack() {
        let store = makeStore()
        let urls = [Fixtures.file("Brief v3.docx", in: "/Users/test/Desktop"), Fixtures.file("q3-numbers.csv", in: "/Users/test/Desktop")]

        XCTAssertEqual(store.stash(urls), 2)
        XCTAssertEqual(store.stash(urls), 0)
        XCTAssertEqual(store.activeSpace.shelves[0].items.count, 2)
        XCTAssertEqual(dock.syncedStacks.last?.count, 2)
    }

    func testProcessFilesMatchingRuleAndSupportsUndo() {
        let rule = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        let store = makeStore(rules: [rule])
        let file = FileCandidate(url: Fixtures.file("invoice-0932.pdf"), source: .downloads, isScreenshot: false, lastUsed: nil)

        XCTAssertEqual(store.process(file)?.id, rule.id)
        XCTAssertEqual(store.layout.spaces[2].shelves[0].items.map(\.name), ["invoice-0932.pdf"])
        XCTAssertTrue(store.canUndoAutomaticMove)

        store.undoLastAutomaticMove()
        XCTAssertTrue(store.layout.spaces[2].shelves[0].items.isEmpty)
        XCTAssertNil(store.lastAutomaticMove)
    }

    func testUndoExpiresAfterTenMinutes() {
        let rule = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        let store = makeStore(rules: [rule])
        store.process(FileCandidate(url: Fixtures.file("menu-proof.pdf"), source: .downloads, isScreenshot: false, lastUsed: nil))

        clock = clock.addingTimeInterval(ShelfStore.undoWindow + 1)
        XCTAssertFalse(store.canUndoAutomaticMove)
    }

    func testRulesDoNothingWhenAutomaticRunsAreOff() {
        let rule = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        let store = makeStore(rules: [rule])
        store.setRunsRulesAutomatically(false)

        XCTAssertNil(store.process(FileCandidate(url: Fixtures.file("a.pdf"), source: .downloads, isScreenshot: false, lastUsed: nil)))
    }

    func testSearchFindsItemsAcrossSpaces() {
        let store = makeStore()
        store.add([Fixtures.file("palette.ase")], toShelf: Fixtures.brand.id)
        store.searchText = "PALETTE"

        XCTAssertEqual(store.searchResults.map(\.space.name), ["Harbor Coffee rebrand"])
    }

    func testOpeningRecordsLastUsedAndOpensThroughDock() {
        let store = makeStore()
        store.add([Fixtures.file("Brief v3.docx")], toShelf: Fixtures.inbox.id)
        let item = store.activeSpace.shelves[0].items[0]

        store.markOpened(item, onShelf: Fixtures.inbox.id)

        XCTAssertEqual(store.activeSpace.shelves[0].items[0].lastOpenedAt, clock)
        XCTAssertEqual(dock.openedItems.map(\.id), [item.id])
    }
}
