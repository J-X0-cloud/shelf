import Combine
import ShelfKit
import XCTest
@testable import Shelf

/// The store is a thin layer over ShelfKit's `LibraryCoordinator` (tested on every platform in
/// ShelfKitTests). These tests cover what the store adds: publishing, error surfacing and drops.
@MainActor
final class ShelfStoreTests: XCTestCase {
    private var persistence: InMemoryLayoutPersistence!
    private var dock: MockDockService!
    private var clock: Date!

    override func setUp() async throws {
        persistence = InMemoryLayoutPersistence(Fixtures.layout())
        dock = MockDockService()
        clock = ISO8601DateFormatter().date(from: "2026-09-24T09:41:00Z")!
    }

    private func makeStore(rules: [Rule] = []) -> ShelfStore {
        persistence.stored = Fixtures.layout(rules: rules)
        let coordinator = LibraryCoordinator(
            persistence: persistence,
            workspace: dock,
            inspector: FileSystemInspector(),
            now: { [unowned self] in self.clock }
        )
        return ShelfStore(coordinator: coordinator, dock: dock)
    }

    func testPublishesEveryChange() {
        let store = makeStore()
        var published: [Space.ID] = []
        let subscription = store.$library.dropFirst().sink { published.append($0.activeSpace.id) }

        store.switchToSpace(shortcut: 2)
        store.switchToSpace(shortcut: 2)
        store.switchToSpace(shortcut: 3)

        XCTAssertEqual(published, [Fixtures.harbor.id, Fixtures.admin.id])
        XCTAssertEqual(persistence.stored?.activeSpaceID, Fixtures.admin.id)
        subscription.cancel()
    }

    func testStashSkipsDuplicatesAndSyncsDockStack() {
        let store = makeStore()
        let urls = [Fixtures.file("Brief v3.docx", in: "/Users/test/Desktop"), Fixtures.file("q3-numbers.csv", in: "/Users/test/Desktop")]

        XCTAssertEqual(store.stash(urls), 2)
        XCTAssertEqual(store.stash(urls), 0)
        XCTAssertEqual(store.activeSpace.shelves[0].items.count, 2)
        XCTAssertEqual(dock.syncedStacks.last?.count, 2)
    }

    func testDraggingATileToAnotherShelfMovesIt() {
        let store = makeStore()
        let archiveID = store.addShelf(named: "Archive")!
        store.stash([Fixtures.file("logo-final.svg")])

        let moved = store.drop(DropPayload(urls: [Fixtures.file("logo-final.svg")]), onShelf: archiveID, at: 0, copying: false)

        XCTAssertTrue(moved)
        XCTAssertTrue(store.activeSpace.shelves[0].items.isEmpty)
        XCTAssertEqual(store.shelf(id: archiveID)?.items.map(\.name), ["logo-final.svg"])
    }

    func testRefusedChangesSurfaceAReason() {
        let store = makeStore()
        XCTAssertNil(store.addSpace(named: "   "))
        XCTAssertEqual(store.lastError, LibraryError.emptyName.description)
        store.clearError()
        XCTAssertNil(store.lastError)
    }

    func testRulesFileAndUndo() {
        let rule = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        let store = makeStore(rules: [rule])

        store.coordinator.process(FileCandidate(url: Fixtures.file("invoice-0932.pdf"), source: .downloads))
        XCTAssertTrue(store.canUndoAutomaticMove)

        store.undoLastAutomaticMove()
        XCTAssertTrue(store.layout.spaces[2].shelves[0].items.isEmpty)
        XCTAssertNil(store.lastAutomaticMove)
    }

    func testSearchFindsItemsAcrossSpaces() {
        let store = makeStore()
        store.drop(DropPayload(urls: [Fixtures.file("palette.ase")]), onShelf: Fixtures.brand.id, at: nil, copying: false)
        store.searchText = "PALETTE"

        XCTAssertEqual(store.searchResults.map(\.space.name), ["Harbor Coffee rebrand"])
    }

    func testOpeningGoesThroughTheDock() {
        let store = makeStore()
        store.stash([Fixtures.file("Brief v3.docx")])
        let item = store.activeSpace.shelves[0].items[0]

        store.open(item, onShelf: Fixtures.inbox.id)

        XCTAssertEqual(store.activeSpace.shelves[0].items[0].lastOpenedAt, clock)
        XCTAssertEqual(dock.openedItems.map(\.id), [item.id])
    }
}
