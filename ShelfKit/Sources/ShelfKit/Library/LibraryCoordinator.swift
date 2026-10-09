import Foundation

/// The system effects a library change can have: keeping the Dock stack in step with the active
/// Space and opening items. The macOS app backs this with NSWorkspace; tests use a recorder.
public protocol WorkspaceServicing: AnyObject {
    /// Rebuilds the Dock stack folder so it mirrors the current Space's shelves.
    func syncDockStack(with items: [ShelfItem]) throws
    func open(_ item: ShelfItem)
}

/// Creates the bookmark stored with a file item. The app uses security-scoped bookmarks.
public typealias BookmarkProvider = (URL) -> Data?

/// Owns the library and applies the side effects of every change: the layout is saved after each
/// commit, the Dock stack is rebuilt only when the active Space's items change, and observers are
/// told. `ShelfStore` in the app is a thin `ObservableObject` over this type.
public final class LibraryCoordinator {
    public private(set) var library: ShelfLibrary
    /// The last error from loading, saving or syncing; surfaced in Settings → General.
    public private(set) var lastError: String?
    /// An error nobody has shown yet. `takeError()` hands it over once.
    private var pendingError: String?

    /// Called after every change that altered the library.
    public var onChange: ((ShelfLibrary) -> Void)?
    /// Called when a change was saved but a side effect failed.
    public var onError: ((String) -> Void)?

    public let engine: RuleEngine
    private let persistence: LayoutPersisting
    private let workspace: WorkspaceServicing
    private let inspector: CandidateInspecting
    private let folders: KnownFolders
    private let bookmark: BookmarkProvider
    private let now: () -> Date

    public init(
        persistence: LayoutPersisting,
        workspace: WorkspaceServicing,
        engine: RuleEngine = RuleEngine(),
        inspector: CandidateInspecting = FileSystemInspector(),
        folders: KnownFolders = .current,
        bookmark: @escaping BookmarkProvider = { _ in nil },
        now: @escaping () -> Date = { Date() }
    ) {
        self.persistence = persistence
        self.workspace = workspace
        self.engine = engine
        self.inspector = inspector
        self.folders = folders
        self.bookmark = bookmark
        self.now = now

        do {
            library = ShelfLibrary(layout: try persistence.load() ?? .starter())
        } catch {
            library = ShelfLibrary(layout: .starter())
            lastError = "Couldn't read the saved layout, so Shelf started fresh: \(error)"
            pendingError = lastError
        }
    }

    // MARK: Reading

    public var layout: ShelfLayout { library.layout }
    public var activeSpace: Space { library.activeSpace }

    public var canUndoAutomaticMove: Bool { library.canUndoAutomaticMove(at: now()) }

    /// The folders Rules currently watch: the active Space's rules plus global ones.
    public var watchedFolders: [(source: Rule.Source, folder: URL)] {
        guard library.layout.runsRulesAutomatically else { return [] }
        return engine.watchedSources(for: library.rules, activeSpaceID: library.activeSpace.id).compactMap { source in
            source.directory(in: folders).map { (source, $0) }
        }
    }

    // MARK: Changing

    /// Applies a change, then saves and syncs if anything actually changed. Errors thrown by the
    /// change are rethrown before anything is written.
    @discardableResult
    public func perform<Result>(_ change: (inout ShelfLibrary) throws -> Result) rethrows -> Result {
        let previousStack = library.activeSpace.allItems
        var draft = library
        let result = try change(&draft)
        guard draft != library else { return result }
        library = draft
        persistAndSync(previousStack: previousStack)
        onChange?(library)
        return result
    }

    /// Makes shelf items for dropped or stashed URLs, with bookmarks and the current date.
    public func makeItems(for urls: [URL]) -> [ShelfItem] {
        let date = now()
        return urls.map { ShelfItem(url: $0, bookmark: $0.isFileURL ? bookmark($0) : nil, addedAt: date) }
    }

    @discardableResult
    public func add(_ urls: [URL], toShelf shelfID: Shelf.ID, at index: Int? = nil) -> Int {
        let items = makeItems(for: urls)
        let added = (try? perform { try $0.add(items, toShelf: shelfID, at: index) }) ?? []
        return added.count
    }

    @discardableResult
    public func stash(_ urls: [URL]) -> Int {
        let items = makeItems(for: urls)
        return ((try? perform { try $0.stash(items) }) ?? []).count
    }

    /// Applies a drop that `DropPlanner` worked out.
    @discardableResult
    public func apply(_ plan: DropPlan) -> Bool {
        switch plan {
        case .ignore:
            return false
        case let .add(urls, shelfID, index):
            return add(urls, toShelf: shelfID, at: index) > 0
        case let .move(itemID, from, to, index):
            return (try? perform { try $0.moveItem(itemID, fromShelf: from, toShelf: to, at: index) }) ?? false
        }
    }

    public func open(_ item: ShelfItem, onShelf shelfID: Shelf.ID) {
        let date = now()
        let opened = perform { $0.markOpened(item.id, onShelf: shelfID, at: date) }
        workspace.open(opened ?? item)
    }

    /// Runs the rules against a file that just appeared in a watched folder.
    @discardableResult
    public func process(_ url: URL, from source: Rule.Source) -> AutomaticMove? {
        process(inspector.inspect(url, source: source))
    }

    @discardableResult
    public func process(_ candidate: FileCandidate) -> AutomaticMove? {
        let date = now()
        let item = ShelfItem(url: candidate.url, bookmark: bookmark(candidate.url), addedAt: date)
        let engine = engine
        return perform { $0.process(candidate, item: item, engine: engine, at: date) }
    }

    /// Applies archive rules to items already on shelves. The app runs this hourly.
    @discardableResult
    public func sweepShelves() -> [AutomaticMove] {
        let date = now()
        let engine = engine
        return perform { $0.sweepShelves(engine: engine, at: date) }
    }

    @discardableResult
    public func undoLastAutomaticMove() -> Bool {
        let date = now()
        return perform { $0.undoLastAutomaticMove(at: date) }
    }

    /// Files the rule would catch right now, for the preview in Settings → Rules.
    public func preview(_ rule: Rule, fileManager: FileManager = .default) -> [FileCandidate] {
        guard let folder = rule.source.directory(in: folders) else {
            return engine.preview(rule, in: library.layout.spaces.flatMap(\.allItems).map(FileCandidate.init(shelfItem:)))
        }
        let urls = (try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let candidates = urls
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { inspector.inspect($0, source: rule.source) }
        return engine.preview(rule, in: candidates)
    }

    // MARK: Import & export

    public func exportLayout(to url: URL) throws {
        try LayoutCoder.exportData(for: library.layout).write(to: url, options: .atomic)
    }

    /// Replaces the current layout with a `.shelfspace` file.
    public func importLayout(from url: URL) throws {
        let imported = try LayoutCoder.decode(Data(contentsOf: url))
        perform { $0.replaceLayout(with: imported) }
    }

    /// Adds a `.shelfspace` template's Spaces next to the current ones.
    @discardableResult
    public func importSpaces(from url: URL) throws -> [Space.ID] {
        let template = try LayoutCoder.decode(Data(contentsOf: url))
        return perform { $0.addSpaces(from: template) }
    }

    // MARK: Side effects

    private func persistAndSync(previousStack: [ShelfItem]) {
        do {
            try persistence.save(library.layout)
        } catch {
            report("Couldn't save the layout: \(error.localizedDescription)")
        }

        // The Dock stack mirrors the active Space; only rebuild it when that set of items changed.
        let stack = library.activeSpace.allItems
        guard stack != previousStack else { return }
        do {
            try workspace.syncDockStack(with: stack)
        } catch {
            report("Couldn't update the Dock stack: \(error.localizedDescription)")
        }
    }

    /// Returns the newest error that hasn't been shown yet, and forgets it.
    public func takeError() -> String? {
        defer { pendingError = nil }
        return pendingError
    }

    private func report(_ message: String) {
        lastError = message
        pendingError = message
        onError?(message)
    }
}
