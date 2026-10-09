import XCTest
@testable import ShelfKit

final class LibraryCoordinatorTests: XCTestCase {
    private var persistence: InMemoryLayoutPersistence!
    private var workspace: RecordingWorkspace!
    private var clock: TestClock!

    override func setUp() {
        super.setUp()
        persistence = InMemoryLayoutPersistence(Fixtures.layout())
        workspace = RecordingWorkspace()
        clock = TestClock()
    }

    private func makeCoordinator(
        rules: [Rule] = [],
        inspector: CandidateInspecting = StubInspector(),
        folders: KnownFolders = Fixtures.folders
    ) -> LibraryCoordinator {
        persistence.stored = Fixtures.layout(rules: rules)
        let clock = clock!
        return LibraryCoordinator(
            persistence: persistence,
            workspace: workspace,
            engine: RuleEngine(now: { clock.now }),
            inspector: inspector,
            folders: folders,
            bookmark: { Data($0.lastPathComponent.utf8) },
            now: { clock.now }
        )
    }

    func testLoadsPersistedLayout() {
        let coordinator = makeCoordinator()
        XCTAssertEqual(coordinator.layout.spaces.map(\.name), ["Studio", "Harbor Coffee rebrand", "Admin & invoices"])
        XCTAssertEqual(coordinator.activeSpace.id, Fixtures.studio.id)
        XCTAssertNil(coordinator.lastError)
    }

    func testFallsBackToStarterLayoutOnFirstLaunch() {
        let coordinator = LibraryCoordinator(persistence: InMemoryLayoutPersistence(), workspace: workspace)
        XCTAssertFalse(coordinator.layout.spaces.isEmpty)
        XCTAssertFalse(coordinator.layout.rules.isEmpty)
    }

    func testUnreadableLayoutStartsFreshAndSaysSo() throws {
        let folder = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("Layout.json")
        try Data("{ not json".utf8).write(to: file)

        let coordinator = LibraryCoordinator(persistence: FileLayoutPersistence(fileURL: file), workspace: workspace)
        XCTAssertEqual(coordinator.layout.spaces.map(\.name), ShelfLayout.starter().spaces.map(\.name))
        XCTAssertNotNil(coordinator.lastError)
        XCTAssertNotNil(coordinator.takeError())
    }

    func testSwitchingPersistsAndNotifies() {
        let coordinator = makeCoordinator()
        var notified = 0
        coordinator.onChange = { _ in notified += 1 }

        coordinator.perform { $0.switchToSpace(shortcut: 2) }
        coordinator.perform { $0.switchToSpace(shortcut: 2) }

        XCTAssertEqual(persistence.stored?.activeSpaceID, Fixtures.harbor.id)
        XCTAssertEqual(persistence.saveCount, 1, "a change that changes nothing isn't saved")
        XCTAssertEqual(notified, 1)
    }

    func testStashSkipsDuplicatesBookmarksFilesAndSyncsDockStack() {
        let coordinator = makeCoordinator()
        let urls = [Fixtures.file("Brief v3.docx", in: "/Users/test/Desktop"), Fixtures.file("q3-numbers.csv", in: "/Users/test/Desktop")]

        XCTAssertEqual(coordinator.stash(urls), 2)
        XCTAssertEqual(coordinator.stash(urls), 0)

        let items = coordinator.activeSpace.shelves[0].items
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].bookmark, Data("Brief v3.docx".utf8))
        XCTAssertEqual(items[0].addedAt, clock.now)
        XCTAssertEqual(workspace.syncedStacks.count, 1)
        XCTAssertEqual(workspace.syncedStacks.last?.count, 2)
    }

    func testDockStackIsOnlyRebuiltWhenTheActiveSpaceChanges() {
        let coordinator = makeCoordinator()
        coordinator.add([Fixtures.file("palette.ase")], toShelf: Fixtures.brand.id)
        XCTAssertTrue(workspace.syncedStacks.isEmpty, "Harbor isn't the active Space")

        coordinator.perform { $0.switchToSpace(id: Fixtures.harbor.id) }
        XCTAssertEqual(workspace.syncedStacks.last?.map(\.name), ["palette.ase"])
    }

    func testProcessFilesMatchingRuleAndSupportsUndo() {
        let rule = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        let coordinator = makeCoordinator(rules: [rule])

        XCTAssertEqual(coordinator.process(Fixtures.file("invoice-0932.pdf"), from: .downloads)?.ruleID, rule.id)
        XCTAssertEqual(coordinator.layout.spaces[2].shelves[0].items.map(\.name), ["invoice-0932.pdf"])
        XCTAssertTrue(coordinator.canUndoAutomaticMove)

        XCTAssertTrue(coordinator.undoLastAutomaticMove())
        XCTAssertTrue(coordinator.layout.spaces[2].shelves[0].items.isEmpty)
        XCTAssertFalse(coordinator.canUndoAutomaticMove)
    }

    func testUndoExpiresAfterTenMinutes() {
        let rule = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        let coordinator = makeCoordinator(rules: [rule])
        coordinator.process(Fixtures.file("menu-proof.pdf"), from: .downloads)

        clock.advance(by: ShelfLibrary.undoWindow + 1)
        XCTAssertFalse(coordinator.canUndoAutomaticMove)
        XCTAssertFalse(coordinator.undoLastAutomaticMove())
    }

    func testScreenshotRuleUsesTheInspector() {
        let rule = Rule(source: .desktop, condition: .isScreenshot, destinationShelfID: Fixtures.inbox.id, spaceID: Fixtures.studio.id)
        let coordinator = makeCoordinator(rules: [rule], inspector: StubInspector(screenshots: ["Screenshot 09.41.png"]))

        XCTAssertNotNil(coordinator.process(Fixtures.file("Screenshot 09.41.png", in: "/Users/test/Desktop"), from: .desktop))
        XCTAssertNil(coordinator.process(Fixtures.file("hero-crop.png", in: "/Users/test/Desktop"), from: .desktop))
    }

    func testWatchedFoldersFollowTheActiveSpaceAndTheSwitch() {
        let rules = [
            Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id),
            Rule(source: .desktop, condition: .isScreenshot, destinationShelfID: Fixtures.brand.id, spaceID: Fixtures.harbor.id),
        ]
        let coordinator = makeCoordinator(rules: rules)
        XCTAssertEqual(coordinator.watchedFolders.map(\.folder.lastPathComponent), ["Downloads"])

        coordinator.perform { $0.switchToSpace(id: Fixtures.harbor.id) }
        XCTAssertEqual(coordinator.watchedFolders.map(\.folder.lastPathComponent), ["Desktop", "Downloads"])

        coordinator.perform { $0.setRunsRulesAutomatically(false) }
        XCTAssertTrue(coordinator.watchedFolders.isEmpty)
    }

    func testOpeningRecordsLastUsedAndOpensThroughWorkspace() {
        let coordinator = makeCoordinator()
        coordinator.add([Fixtures.file("Brief v3.docx")], toShelf: Fixtures.inbox.id)
        let item = coordinator.activeSpace.shelves[0].items[0]

        clock.advance(by: 60)
        coordinator.open(item, onShelf: Fixtures.inbox.id)

        XCTAssertEqual(coordinator.activeSpace.shelves[0].items[0].lastOpenedAt, clock.now)
        XCTAssertEqual(workspace.openedItems.map(\.id), [item.id])
    }

    func testDropPlansApply() {
        let coordinator = makeCoordinator()
        coordinator.add([Fixtures.file("logo-final.svg")], toShelf: Fixtures.inbox.id)
        let item = coordinator.activeSpace.shelves[0].items[0]

        XCTAssertFalse(coordinator.apply(.ignore))
        XCTAssertTrue(coordinator.apply(.move(itemID: item.id, fromShelf: Fixtures.inbox.id, toShelf: Fixtures.archive.id, at: nil)))
        XCTAssertEqual(coordinator.activeSpace.shelves[1].items.map(\.id), [item.id])
        XCTAssertTrue(coordinator.apply(.add([URL(string: "https://shelfapp.com")!], toShelf: Fixtures.inbox.id, at: 0)))
        XCTAssertEqual(coordinator.activeSpace.shelves[0].items.map(\.kind), [.link])
    }

    func testFailedSavesAndSyncsAreReported() {
        let coordinator = makeCoordinator()
        var reported: [String] = []
        coordinator.onError = { reported.append($0) }

        persistence.failNextSave = true
        workspace.failSync = true
        coordinator.add([Fixtures.file("a.pdf")], toShelf: Fixtures.inbox.id)

        XCTAssertEqual(reported.count, 2)
        XCTAssertEqual(coordinator.lastError, reported.last)
        XCTAssertEqual(coordinator.takeError(), reported.last)
        XCTAssertNil(coordinator.takeError(), "each error is handed over once")
        XCTAssertEqual(coordinator.activeSpace.shelves[0].items.count, 1, "the change itself still applies")
    }

    func testPreviewReadsTheWatchedFolder() throws {
        let downloads = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: downloads) }
        for name in ["invoice-0932.pdf", "brief.docx", "menu.PDF", ".hidden.pdf"] {
            try Data().write(to: downloads.appendingPathComponent(name))
        }
        let coordinator = makeCoordinator(folders: KnownFolders(downloads: downloads, desktop: nil))
        let rule = Rule(isEnabled: false, source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)

        XCTAssertEqual(coordinator.preview(rule).map(\.fileName), ["invoice-0932.pdf", "menu.PDF"])
    }

    func testExportAndImportThroughFiles() throws {
        let folder = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("Studio.\(LayoutCoder.fileExtension)")

        let coordinator = makeCoordinator()
        coordinator.add([Fixtures.file("Brief v3.docx")], toShelf: Fixtures.inbox.id)
        try coordinator.exportLayout(to: file)

        let other = LibraryCoordinator(persistence: InMemoryLayoutPersistence(.starter()), workspace: workspace)
        let added = try other.importSpaces(from: file)
        XCTAssertEqual(added.count, 3)
        XCTAssertEqual(other.layout.spaces.count, 5)

        try other.importLayout(from: file)
        XCTAssertEqual(other.layout.spaces.map(\.id), coordinator.layout.spaces.map(\.id))
        XCTAssertNil(other.layout.spaces[0].shelves[0].items[0].bookmark)
    }
}
