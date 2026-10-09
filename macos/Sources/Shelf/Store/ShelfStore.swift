import Combine
import Foundation
import OSLog
import ShelfKit

/// The SwiftUI face of `LibraryCoordinator`. Views observe it; every change goes through the
/// coordinator so the layout is saved and the Dock stack stays in sync. The store also owns the
/// AppKit-only parts of Rules: the folder watchers and the hourly archive sweep.
@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var library: ShelfLibrary
    @Published private(set) var lastError: String?
    @Published var shelvesHidden = false
    @Published var searchText = ""

    let coordinator: LibraryCoordinator
    private let dock: DockServicing
    private var watchers: [FolderWatcher] = []
    private var sweepTimer: Timer?
    private let logger = Logger(subsystem: "com.shelfapp.Shelf", category: "Store")

    init(coordinator: LibraryCoordinator, dock: DockServicing) {
        self.coordinator = coordinator
        self.dock = dock
        library = coordinator.library
        lastError = coordinator.takeError()
    }

    static func live() -> ShelfStore {
        let dock = WorkspaceDockService()
        let coordinator = LibraryCoordinator(
            persistence: FileLayoutPersistence(),
            workspace: dock,
            inspector: SpotlightInspector(),
            bookmark: ShelfStore.bookmark(for:)
        )
        return ShelfStore(coordinator: coordinator, dock: dock)
    }

    // MARK: Reading

    var layout: ShelfLayout { library.layout }
    var spaces: [Space] { library.spaces }
    var rules: [Rule] { library.rules }
    var activeSpace: Space { library.activeSpace }
    var lastAutomaticMove: AutomaticMove? { library.lastAutomaticMove }
    var canUndoAutomaticMove: Bool { coordinator.canUndoAutomaticMove }

    var searchResults: [SearchResult] { library.search(searchText) }

    func shelf(id: Shelf.ID) -> Shelf? { library.layout.shelf(id: id) }
    func shelfName(id: Shelf.ID) -> String? { library.shelfName(id: id) }
    func spaceName(id: Space.ID?) -> String? { library.spaceName(id: id) }

    // MARK: Spaces

    func switchToSpace(id: Space.ID) {
        if run({ $0.switchToSpace(id: id) }) { restartWatching() }
    }

    /// ⌘1–9. Index is 1-based to match the shortcut.
    func switchToSpace(shortcut index: Int) {
        if run({ $0.switchToSpace(shortcut: index) }) { restartWatching() }
    }

    @discardableResult
    func addSpace(named name: String) -> Space.ID? {
        attempt { try $0.addSpace(named: name) }
    }

    func renameSpace(_ id: Space.ID, to name: String) {
        attempt { try $0.renameSpace(id, to: name) }
    }

    func deleteSpace(_ id: Space.ID) {
        attempt { try $0.deleteSpace(id) }
        restartWatching()
    }

    func moveSpaces(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        run { $0.moveSpaces(fromOffsets: offsets, toOffset: destination) }
    }

    // MARK: Shelves and items

    @discardableResult
    func addShelf(named name: String = "New shelf") -> Shelf.ID? {
        let color = activeSpace.colorHex
        return attempt { try $0.addShelf(named: name, colorHex: color) }
    }

    func updateShelf(_ id: Shelf.ID, _ change: @escaping (inout Shelf) -> Void) {
        attempt { try $0.updateShelf(id, change) }
    }

    func deleteShelf(_ id: Shelf.ID) {
        attempt { try $0.deleteShelf(id) }
        restartWatching()
    }

    /// Handles a drop onto a shelf: a tile from another shelf moves, anything else is added.
    @discardableResult
    func drop(_ payload: DropPayload, onShelf shelfID: Shelf.ID, at index: Int?, copying: Bool) -> Bool {
        let plan = DropPlanner().plan(payload, ontoShelf: shelfID, at: index, in: layout, copies: copying)
        defer { refresh() }
        return coordinator.apply(plan)
    }

    /// ⇧⌘S: sweep the Finder selection onto the first shelf of the active Space. Originals stay put.
    @discardableResult
    func stash(_ urls: [URL]) -> Int {
        defer { refresh() }
        return coordinator.stash(urls)
    }

    func removeItem(_ itemID: ShelfItem.ID, fromShelf shelfID: Shelf.ID) {
        run { $0.removeItem(itemID, fromShelf: shelfID) }
    }

    func open(_ item: ShelfItem, onShelf shelfID: Shelf.ID) {
        coordinator.open(item, onShelf: shelfID)
        refresh()
    }

    func revealInFinder(_ items: [ShelfItem]) {
        dock.revealInFinder(items)
    }

    func toggleShelvesHidden() {
        shelvesHidden.toggle()
    }

    // MARK: Rules

    func setRunsRulesAutomatically(_ enabled: Bool) {
        run { $0.setRunsRulesAutomatically(enabled) }
        restartWatching()
    }

    func addRule(_ rule: Rule) {
        attempt { try $0.addRule(rule) }
        restartWatching()
    }

    func setRule(_ id: Rule.ID, enabled: Bool) {
        run { $0.setRule(id, enabled: enabled) }
        restartWatching()
    }

    func deleteRule(_ id: Rule.ID) {
        run { $0.deleteRule(id) }
        restartWatching()
    }

    func moveRules(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        run { $0.moveRules(fromOffsets: offsets, toOffset: destination) }
    }

    func preview(_ rule: Rule) -> [FileCandidate] {
        coordinator.preview(rule)
    }

    func undoLastAutomaticMove() {
        coordinator.undoLastAutomaticMove()
        refresh()
    }

    // MARK: Watching folders

    /// Watches the folders the active Space's rules (and global rules) care about, and runs the
    /// archive sweep once an hour.
    func startWatching() {
        stopWatching()
        for (source, folder) in coordinator.watchedFolders {
            let watcher = FolderWatcher(folder: folder) { [weak self] urls in
                Task { @MainActor in
                    guard let self else { return }
                    for url in urls {
                        if let move = self.coordinator.process(url, from: source) {
                            self.logger.info("Rule filed \(move.item.name, privacy: .private) onto a shelf")
                        }
                    }
                    self.refresh()
                }
            }
            watcher.start()
            watchers.append(watcher)
        }

        guard layout.runsRulesAutomatically else { return }
        sweepShelves()
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sweepShelves() }
        }
    }

    /// Applies archive rules ("untouched for 30 days") to items already on shelves.
    func sweepShelves() {
        coordinator.sweepShelves()
        refresh()
    }

    func stopWatching() {
        watchers.forEach { $0.stop() }
        watchers.removeAll()
        sweepTimer?.invalidate()
        sweepTimer = nil
    }

    private var isWatching: Bool { !watchers.isEmpty || sweepTimer != nil }

    private func restartWatching() {
        if isWatching || layout.runsRulesAutomatically { startWatching() }
    }

    // MARK: Import & export

    func exportLayout(to url: URL) throws {
        try coordinator.exportLayout(to: url)
    }

    func importLayout(from url: URL) throws {
        try coordinator.importLayout(from: url)
        refresh()
        restartWatching()
    }

    func importSpaces(from url: URL) throws {
        try coordinator.importSpaces(from: url)
        refresh()
    }

    // MARK: Helpers

    func clearError() {
        lastError = nil
    }

    /// Applies a change through the coordinator and publishes the result.
    @discardableResult
    private func run<T>(_ change: (inout ShelfLibrary) -> T) -> T {
        defer { refresh() }
        return coordinator.perform(change)
    }

    /// Like `run`, for changes that can be refused. The reason is shown in Settings.
    @discardableResult
    private func attempt<T>(_ change: (inout ShelfLibrary) throws -> T) -> T? {
        defer { refresh() }
        do {
            return try coordinator.perform(change)
        } catch {
            lastError = (error as? LibraryError)?.description ?? error.localizedDescription
            return nil
        }
    }

    /// Copies the coordinator's state into the published properties.
    private func refresh() {
        if coordinator.library != library { library = coordinator.library }
        if let error = coordinator.takeError() {
            lastError = error
            logger.error("\(error, privacy: .public)")
        }
    }

    nonisolated static func bookmark(for url: URL) -> Data? {
        guard url.isFileURL else { return nil }
        return try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
