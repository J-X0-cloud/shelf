import Combine
import Foundation
import OSLog

/// Records an automatic move so it can be undone from the menu bar.
struct AutomaticMove: Equatable {
    let item: ShelfItem
    let shelfID: Shelf.ID
    let ruleID: Rule.ID
    let date: Date
}

struct SearchResult: Identifiable {
    let space: Space
    let shelf: Shelf
    let item: ShelfItem

    var id: ShelfItem.ID { item.id }
}

/// The single source of truth for Spaces, shelves and Rules. Views observe it; every mutation
/// goes through `commit` so the layout is saved and the Dock stack stays in sync.
@MainActor
final class ShelfStore: ObservableObject {
    /// How long "Undo last rule action" stays available.
    static let undoWindow: TimeInterval = 10 * 60

    @Published private(set) var layout: ShelfLayout
    @Published private(set) var lastAutomaticMove: AutomaticMove? = nil
    @Published var shelvesHidden = false
    @Published var searchText = ""

    private let persistence: LayoutPersisting
    private let dock: DockServicing
    private let engine: RuleEngine
    private let now: () -> Date
    private var watchers: [FolderWatcher] = []
    private let logger = Logger(subsystem: "com.shelfapp.Shelf", category: "Store")

    init(
        persistence: LayoutPersisting,
        dock: DockServicing,
        engine: RuleEngine = RuleEngine(),
        now: @escaping () -> Date = Date.init
    ) {
        self.persistence = persistence
        self.dock = dock
        self.engine = engine
        self.now = now

        do {
            layout = try persistence.load() ?? .starter()
        } catch {
            layout = .starter()
            Logger(subsystem: "com.shelfapp.Shelf", category: "Store")
                .error("Couldn't read layout, starting fresh: \(error.localizedDescription)")
        }
    }

    static func live() -> ShelfStore {
        ShelfStore(persistence: FileLayoutPersistence(), dock: WorkspaceDockService())
    }

    // MARK: Reading

    var spaces: [Space] { layout.spaces }
    var rules: [Rule] { layout.rules }

    var activeSpace: Space {
        layout.spaces.first { $0.id == layout.activeSpaceID } ?? layout.spaces[0]
    }

    /// Items across every shelf in every Space whose name matches the search text.
    var searchResults: [SearchResult] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return layout.spaces.flatMap { space in
            space.shelves.flatMap { shelf in
                shelf.items
                    .filter { $0.name.localizedCaseInsensitiveContains(query) }
                    .map { SearchResult(space: space, shelf: shelf, item: $0) }
            }
        }
    }

    func shelfName(id: Shelf.ID) -> String? {
        guard let location = layout.location(ofShelf: id) else { return nil }
        return layout.spaces[location.space].shelves[location.shelf].name
    }

    func spaceName(id: Space.ID?) -> String? {
        guard let id, let index = layout.spaceIndex(id: id) else { return nil }
        return layout.spaces[index].name
    }

    // MARK: Spaces

    func switchToSpace(id: Space.ID) {
        guard layout.spaceIndex(id: id) != nil, id != layout.activeSpaceID else { return }
        commit { $0.activeSpaceID = id }
    }

    /// ⌘1–9. Index is 1-based to match the shortcut.
    func switchToSpace(shortcut index: Int) {
        guard (1 ... 9).contains(index), index <= layout.spaces.count else { return }
        switchToSpace(id: layout.spaces[index - 1].id)
    }

    @discardableResult
    func addSpace(named name: String, colorHex: String) -> Space.ID {
        let space = Space(name: name, colorHex: colorHex, shelves: [Shelf(name: "Inbox", colorHex: colorHex)])
        commit { $0.spaces.append(space) }
        return space.id
    }

    // MARK: Shelves

    @discardableResult
    func addShelf(named name: String, colorHex: String, to spaceID: Space.ID? = nil) -> Shelf.ID? {
        guard let index = layout.spaceIndex(id: spaceID ?? activeSpace.id) else { return nil }
        let shelf = Shelf(name: name, colorHex: colorHex)
        commit { $0.spaces[index].shelves.append(shelf) }
        return shelf.id
    }

    /// Adds URLs to a shelf, skipping ones that are already there. Returns the number added.
    @discardableResult
    func add(_ urls: [URL], toShelf shelfID: Shelf.ID) -> Int {
        guard let location = layout.location(ofShelf: shelfID) else { return 0 }
        var added = 0
        commit { layout in
            for url in urls {
                let item = ShelfItem(url: url, bookmark: Self.bookmark(for: url), addedAt: now())
                if layout.spaces[location.space].shelves[location.shelf].add(item) { added += 1 }
            }
        }
        return added
    }

    /// ⇧⌘S: sweep a selection onto the first shelf of the active Space. Originals stay put.
    @discardableResult
    func stash(_ urls: [URL]) -> Int {
        guard let shelf = activeSpace.shelves.first else {
            guard let id = addShelf(named: "Stash", colorHex: activeSpace.colorHex) else { return 0 }
            return add(urls, toShelf: id)
        }
        return add(urls, toShelf: shelf.id)
    }

    func removeItem(_ itemID: ShelfItem.ID, fromShelf shelfID: Shelf.ID) {
        guard let location = layout.location(ofShelf: shelfID) else { return }
        commit { $0.spaces[location.space].shelves[location.shelf].removeItem(id: itemID) }
    }

    func markOpened(_ item: ShelfItem, onShelf shelfID: Shelf.ID) {
        guard let location = layout.location(ofShelf: shelfID),
              let itemIndex = layout.spaces[location.space].shelves[location.shelf].items.firstIndex(where: { $0.id == item.id })
        else { return }
        commit { $0.spaces[location.space].shelves[location.shelf].items[itemIndex].lastOpenedAt = now() }
        dock.open(item)
    }

    func toggleShelvesHidden() {
        shelvesHidden.toggle()
    }

    // MARK: Rules

    func setRunsRulesAutomatically(_ enabled: Bool) {
        commit { $0.runsRulesAutomatically = enabled }
        if enabled {
            startWatching()
        } else {
            stopWatching()
        }
    }

    func addRule(_ rule: Rule) {
        commit { $0.rules.append(rule) }
        restartWatching()
    }

    func setRule(_ id: Rule.ID, enabled: Bool) {
        guard let index = layout.rules.firstIndex(where: { $0.id == id }) else { return }
        commit { $0.rules[index].isEnabled = enabled }
        restartWatching()
    }

    func deleteRule(_ id: Rule.ID) {
        commit { $0.rules.removeAll { $0.id == id } }
        restartWatching()
    }

    /// Files the rule would catch right now, for the preview in Settings → Rules.
    func preview(_ rule: Rule) -> [FileCandidate] {
        guard let folder = rule.source.directory() else {
            let candidates = layout.spaces.flatMap(\.shelves).flatMap(\.items).map {
                FileCandidate(url: $0.url, source: .anyShelf, isScreenshot: false, lastUsed: $0.lastUsed)
            }
            return engine.preview(rule, in: candidates)
        }
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return engine.preview(rule, in: urls.map { FileCandidate.inspect($0, source: rule.source) })
    }

    /// Runs the rules against one file. Returns the rule that moved it, if any.
    @discardableResult
    func process(_ candidate: FileCandidate) -> Rule? {
        guard layout.runsRulesAutomatically,
              let rule = engine.firstMatch(in: layout.rules, for: candidate, activeSpaceID: layout.activeSpaceID),
              let location = layout.location(ofShelf: rule.destinationShelfID)
        else { return nil }

        let item = ShelfItem(url: candidate.url, bookmark: Self.bookmark(for: candidate.url), addedAt: now())
        var added = false
        commit { added = $0.spaces[location.space].shelves[location.shelf].add(item) }
        guard added else { return nil }

        lastAutomaticMove = AutomaticMove(item: item, shelfID: rule.destinationShelfID, ruleID: rule.id, date: now())
        logger.info("Rule filed \(candidate.fileName, privacy: .private) onto a shelf")
        return rule
    }

    var canUndoAutomaticMove: Bool {
        guard let move = lastAutomaticMove else { return false }
        return now().timeIntervalSince(move.date) <= Self.undoWindow
    }

    func undoLastAutomaticMove() {
        guard canUndoAutomaticMove, let move = lastAutomaticMove else { return }
        removeItem(move.item.id, fromShelf: move.shelfID)
        lastAutomaticMove = nil
    }

    // MARK: Watching folders

    func startWatching() {
        stopWatching()
        guard layout.runsRulesAutomatically else { return }

        let sources = Set(layout.rules.filter(\.isEnabled).map(\.source))
        for source in sources {
            guard let folder = source.directory() else { continue }
            let watcher = FolderWatcher(folder: folder) { [weak self] urls in
                Task { @MainActor in
                    guard let self else { return }
                    for url in urls {
                        self.process(FileCandidate.inspect(url, source: source))
                    }
                }
            }
            watcher.start()
            watchers.append(watcher)
        }
    }

    func stopWatching() {
        watchers.forEach { $0.stop() }
        watchers.removeAll()
    }

    private func restartWatching() {
        if !watchers.isEmpty { startWatching() }
    }

    // MARK: Import & export

    func exportLayout(to url: URL) throws {
        try LayoutCoder.encoder.encode(layout).write(to: url, options: .atomic)
    }

    func importLayout(from url: URL) throws {
        let imported = try LayoutCoder.decoder.decode(ShelfLayout.self, from: Data(contentsOf: url))
        commit { $0 = imported }
        restartWatching()
    }

    // MARK: Persistence

    private func commit(_ mutate: (inout ShelfLayout) -> Void) {
        let previousStack = activeSpace.shelves.flatMap(\.items)
        var draft = layout
        mutate(&draft)
        guard draft != layout else { return }
        layout = draft

        do {
            try persistence.save(layout)
        } catch {
            logger.error("Couldn't save layout: \(error.localizedDescription)")
        }

        // The Dock stack mirrors the active Space; only rebuild it when that set of items changed.
        let stack = activeSpace.shelves.flatMap(\.items)
        guard stack != previousStack else { return }
        do {
            try dock.syncDockStack(with: stack)
        } catch {
            logger.error("Couldn't sync Dock stack: \(error.localizedDescription)")
        }
    }

    private static func bookmark(for url: URL) -> Data? {
        guard url.isFileURL else { return nil }
        return try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
