import Foundation

/// Records an automatic move so it can be undone from the menu bar.
public struct AutomaticMove: Equatable, Sendable {
    public let item: ShelfItem
    public let shelfID: Shelf.ID
    /// Where the item was before, for archive rules that move items between shelves.
    /// `nil` when a rule filed a new arrival from a watched folder.
    public let previousShelfID: Shelf.ID?
    public let ruleID: Rule.ID
    public let date: Date

    public init(item: ShelfItem, shelfID: Shelf.ID, previousShelfID: Shelf.ID? = nil, ruleID: Rule.ID, date: Date) {
        self.item = item
        self.shelfID = shelfID
        self.previousShelfID = previousShelfID
        self.ruleID = ruleID
        self.date = date
    }
}

public struct SearchResult: Identifiable, Equatable, Sendable {
    public let space: Space
    public let shelf: Shelf
    public let item: ShelfItem

    public var id: ShelfItem.ID { item.id }
}

public enum LibraryError: Error, Equatable, CustomStringConvertible {
    case unknownShelf
    case unknownSpace
    case invalidRule
    case emptyName
    case lastSpace

    public var description: String {
        switch self {
        case .unknownShelf: "That shelf no longer exists."
        case .unknownSpace: "That Space no longer exists."
        case .invalidRule: "The rule needs a condition that can match something."
        case .emptyName: "Names can't be empty."
        case .lastSpace: "Shelf needs at least one Space."
        }
    }
}

/// Every change Shelf can make to the layout, as plain value semantics. `LibraryCoordinator`
/// adds persistence and side effects on top; the menu bar, panels and Settings only call through it.
public struct ShelfLibrary: Equatable, Sendable {
    /// How long "Undo last rule action" stays available.
    public static let undoWindow: TimeInterval = 10 * 60
    /// Colours offered when creating a Space or shelf.
    public static let palette = ["#E4572E", "#5E9C7E", "#E9B44C", "#7FA7D9", "#8A5CD6", "#3F7BD0", "#C7431D", "#8B939C"]

    public private(set) var layout: ShelfLayout
    public private(set) var lastAutomaticMove: AutomaticMove?

    public init(layout: ShelfLayout) {
        var layout = layout
        layout.normalize()
        self.layout = layout
    }

    // MARK: Reading

    public var spaces: [Space] { layout.spaces }
    public var rules: [Rule] { layout.rules }

    /// `normalize()` guarantees at least one Space, so this never traps.
    public var activeSpace: Space { layout.activeSpace ?? layout.spaces[0] }

    /// The next colour from the palette, so new Spaces don't all look the same.
    public var nextSpaceColor: String {
        ShelfLibrary.palette[layout.spaces.count % ShelfLibrary.palette.count]
    }

    /// Items across every shelf in every Space whose name (or, for links, address) matches.
    /// Results from the active Space come first.
    public func search(_ text: String) -> [SearchResult] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let activeID = activeSpace.id
        let ordered = layout.spaces.filter { $0.id == activeID } + layout.spaces.filter { $0.id != activeID }
        return ordered.flatMap { space in
            space.shelves.flatMap { shelf in
                shelf.items
                    .filter { item in
                        item.name.range(of: query, options: options) != nil
                            || (item.kind == .link && item.url.absoluteString.range(of: query, options: options) != nil)
                    }
                    .map { SearchResult(space: space, shelf: shelf, item: $0) }
            }
        }
    }

    public func shelfName(id: Shelf.ID) -> String? {
        layout.shelf(id: id)?.name
    }

    public func spaceName(id: Space.ID?) -> String? {
        guard let id, let index = layout.spaceIndex(id: id) else { return nil }
        return layout.spaces[index].name
    }

    /// The Space that holds a shelf.
    public func space(containingShelf id: Shelf.ID) -> Space? {
        layout.location(ofShelf: id).map { layout.spaces[$0.space] }
    }

    // MARK: Spaces

    @discardableResult
    public mutating func switchToSpace(id: Space.ID) -> Bool {
        guard layout.spaceIndex(id: id) != nil, id != layout.activeSpaceID else { return false }
        layout.activeSpaceID = id
        return true
    }

    /// ⌘1–9. Index is 1-based to match the shortcut.
    @discardableResult
    public mutating func switchToSpace(shortcut index: Int) -> Bool {
        guard (1 ... 9).contains(index), index <= layout.spaces.count else { return false }
        return switchToSpace(id: layout.spaces[index - 1].id)
    }

    /// Brings forward the first Space linked to a Focus mode that just turned on.
    @discardableResult
    public mutating func focusModeDidActivate(_ focusMode: String) -> Bool {
        guard let space = layout.spaces.first(where: { $0.follows(focusMode: focusMode) }) else { return false }
        return switchToSpace(id: space.id)
    }

    /// The ⌘-number shown next to a Space in the menu, if it has one.
    public func shortcutLabel(forSpace id: Space.ID) -> String? {
        guard let index = layout.spaceIndex(id: id), index < 9 else { return nil }
        return "⌘\(index + 1)"
    }

    @discardableResult
    public mutating func addSpace(named name: String, colorHex: String? = nil) throws -> Space.ID {
        let name = try Self.validatedName(name)
        let color = colorHex ?? nextSpaceColor
        let space = Space(name: name, colorHex: color, shelves: [Shelf(name: "Inbox", colorHex: color)])
        layout.spaces.append(space)
        return space.id
    }

    public mutating func renameSpace(_ id: Space.ID, to name: String) throws {
        guard let index = layout.spaceIndex(id: id) else { throw LibraryError.unknownSpace }
        layout.spaces[index].name = try Self.validatedName(name)
    }

    public mutating func setFocusModes(_ modes: [String], forSpace id: Space.ID) throws {
        guard let index = layout.spaceIndex(id: id) else { throw LibraryError.unknownSpace }
        var seen = Set<String>()
        layout.spaces[index].focusModes = modes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    /// Deletes a Space with its shelves, and every rule that belonged to it or filed onto its shelves.
    public mutating func deleteSpace(_ id: Space.ID) throws {
        guard let index = layout.spaceIndex(id: id) else { throw LibraryError.unknownSpace }
        guard layout.spaces.count > 1 else { throw LibraryError.lastSpace }
        let shelfIDs = Set(layout.spaces[index].shelves.map(\.id))
        layout.spaces.remove(at: index)
        layout.rules.removeAll { $0.spaceID == id || shelfIDs.contains($0.destinationShelfID) }
        if layout.activeSpaceID == id {
            layout.activeSpaceID = layout.spaces[min(index, layout.spaces.count - 1)].id
        }
        if let move = lastAutomaticMove, shelfIDs.contains(move.shelfID) {
            lastAutomaticMove = nil
        }
    }

    /// Reorders Spaces, which also changes their ⌘-number shortcuts.
    public mutating func moveSpaces(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        layout.spaces.move(fromOffsets: offsets, toOffset: destination)
    }

    // MARK: Shelves

    @discardableResult
    public mutating func addShelf(named name: String, colorHex: String, to spaceID: Space.ID? = nil) throws -> Shelf.ID {
        guard let index = layout.spaceIndex(id: spaceID ?? activeSpace.id) else { throw LibraryError.unknownSpace }
        let shelf = Shelf(name: try Self.validatedName(name), colorHex: colorHex)
        layout.spaces[index].shelves.append(shelf)
        return shelf.id
    }

    public mutating func updateShelf(_ id: Shelf.ID, _ change: (inout Shelf) -> Void) throws {
        guard let location = layout.location(ofShelf: id) else { throw LibraryError.unknownShelf }
        var shelf = layout[location]
        change(&shelf)
        shelf.id = id
        shelf.name = try Self.validatedName(shelf.name)
        layout[location] = shelf
    }

    /// Deletes a shelf. Rules that filed onto it are removed too, so nothing points at a missing shelf.
    public mutating func deleteShelf(_ id: Shelf.ID) throws {
        guard let location = layout.location(ofShelf: id) else { throw LibraryError.unknownShelf }
        layout.spaces[location.space].shelves.remove(at: location.shelf)
        layout.rules.removeAll { $0.destinationShelfID == id }
        if lastAutomaticMove?.shelfID == id { lastAutomaticMove = nil }
    }

    // MARK: Items

    /// Adds items to a shelf at `index` (the end when `nil`), skipping URLs already there.
    /// Returns the items that were added.
    @discardableResult
    public mutating func add(_ items: [ShelfItem], toShelf shelfID: Shelf.ID, at index: Int? = nil) throws -> [ShelfItem] {
        guard let location = layout.location(ofShelf: shelfID) else { throw LibraryError.unknownShelf }
        var shelf = layout[location]
        var insertionPoint = min(max(index ?? shelf.items.endIndex, 0), shelf.items.endIndex)
        var added: [ShelfItem] = []
        for item in items where shelf.insert(item, at: insertionPoint) {
            insertionPoint += 1
            added.append(item)
        }
        layout[location] = shelf
        return added
    }

    /// ⇧⌘S: sweep a selection onto the first shelf of the active Space. Originals stay put.
    /// Creates a "Stash" shelf when the Space has none.
    @discardableResult
    public mutating func stash(_ items: [ShelfItem]) throws -> [ShelfItem] {
        let target: Shelf.ID
        if let first = activeSpace.shelves.first {
            target = first.id
        } else {
            target = try addShelf(named: "Stash", colorHex: activeSpace.colorHex)
        }
        return try add(items, toShelf: target)
    }

    @discardableResult
    public mutating func removeItem(_ itemID: ShelfItem.ID, fromShelf shelfID: Shelf.ID) -> ShelfItem? {
        guard let location = layout.location(ofShelf: shelfID) else { return nil }
        let removed = layout.spaces[location.space].shelves[location.shelf].removeItem(id: itemID)
        if removed != nil, lastAutomaticMove?.item.id == itemID { lastAutomaticMove = nil }
        return removed
    }

    /// Moves an item to another shelf (in any Space), or to a new position on the same shelf.
    /// If the destination already holds the same URL, the duplicate is dropped instead.
    @discardableResult
    public mutating func moveItem(
        _ itemID: ShelfItem.ID,
        fromShelf sourceID: Shelf.ID,
        toShelf destinationID: Shelf.ID,
        at index: Int? = nil
    ) throws -> Bool {
        guard let source = layout.location(ofShelf: sourceID) else { throw LibraryError.unknownShelf }
        guard let destination = layout.location(ofShelf: destinationID) else { throw LibraryError.unknownShelf }
        guard let from = layout[source].itemIndex(id: itemID) else { return false }

        if source == destination {
            let target = index ?? layout[source].items.endIndex
            layout[source].moveItems(fromOffsets: IndexSet(integer: from), toOffset: target)
            return true
        }

        let item = layout[source].items[from]
        layout[source].items.remove(at: from)
        var target = layout[destination]
        target.insert(item, at: index ?? target.items.endIndex)
        layout[destination] = target
        return true
    }

    public mutating func reorderItems(onShelf shelfID: Shelf.ID, fromOffsets offsets: IndexSet, toOffset destination: Int) throws {
        guard let location = layout.location(ofShelf: shelfID) else { throw LibraryError.unknownShelf }
        layout[location].moveItems(fromOffsets: offsets, toOffset: destination)
    }

    /// Records that an item was opened. Returns the updated item.
    @discardableResult
    public mutating func markOpened(_ itemID: ShelfItem.ID, onShelf shelfID: Shelf.ID, at date: Date) -> ShelfItem? {
        guard let location = layout.location(ofShelf: shelfID),
              let itemIndex = layout[location].itemIndex(id: itemID)
        else { return nil }
        layout.spaces[location.space].shelves[location.shelf].items[itemIndex].lastOpenedAt = date
        return layout[location].items[itemIndex]
    }

    /// Replaces the bookmark and URL of an item after its file moved on disk.
    public mutating func relink(_ itemID: ShelfItem.ID, onShelf shelfID: Shelf.ID, to url: URL, bookmark: Data?) {
        guard let location = layout.location(ofShelf: shelfID),
              let itemIndex = layout[location].itemIndex(id: itemID)
        else { return }
        layout.spaces[location.space].shelves[location.shelf].items[itemIndex].url = url
        layout.spaces[location.space].shelves[location.shelf].items[itemIndex].bookmark = bookmark
    }

    // MARK: Rules

    public mutating func setRunsRulesAutomatically(_ enabled: Bool) {
        layout.runsRulesAutomatically = enabled
    }

    public mutating func addRule(_ rule: Rule) throws {
        try validate(rule)
        layout.rules.append(rule)
    }

    public mutating func updateRule(_ rule: Rule) throws {
        guard let index = layout.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        try validate(rule)
        layout.rules[index] = rule
    }

    public mutating func setRule(_ id: Rule.ID, enabled: Bool) {
        guard let index = layout.rules.firstIndex(where: { $0.id == id }) else { return }
        layout.rules[index].isEnabled = enabled
    }

    public mutating func deleteRule(_ id: Rule.ID) {
        layout.rules.removeAll { $0.id == id }
    }

    public mutating func moveRules(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        layout.rules.move(fromOffsets: offsets, toOffset: destination)
    }

    private func validate(_ rule: Rule) throws {
        guard rule.condition.isValid else { throw LibraryError.invalidRule }
        guard layout.location(ofShelf: rule.destinationShelfID) != nil else { throw LibraryError.unknownShelf }
        if let spaceID = rule.spaceID, layout.spaceIndex(id: spaceID) == nil { throw LibraryError.unknownSpace }
    }

    /// Runs the rules against one new file. Returns the move it made, if any.
    @discardableResult
    public mutating func process(_ candidate: FileCandidate, item: ShelfItem, engine: RuleEngine, at date: Date) -> AutomaticMove? {
        guard layout.runsRulesAutomatically,
              let rule = engine.firstMatch(in: layout.rules, for: candidate, activeSpaceID: activeSpace.id),
              let location = layout.location(ofShelf: rule.destinationShelfID),
              layout.spaces[location.space].shelves[location.shelf].add(item)
        else { return nil }

        let move = AutomaticMove(item: item, shelfID: rule.destinationShelfID, ruleID: rule.id, date: date)
        lastAutomaticMove = move
        return move
    }

    /// Applies "Any shelf" rules (such as archiving items untouched for 30 days) to everything on
    /// the shelves. Items already on a rule's destination shelf stay where they are.
    @discardableResult
    public mutating func sweepShelves(engine: RuleEngine, at date: Date) -> [AutomaticMove] {
        guard layout.runsRulesAutomatically else { return [] }
        var moves: [AutomaticMove] = []
        for space in layout.spaces {
            for shelf in space.shelves {
                for item in shelf.items {
                    let candidate = FileCandidate(shelfItem: item)
                    guard let rule = engine.firstMatch(in: layout.rules, for: candidate, activeSpaceID: space.id),
                          rule.destinationShelfID != shelf.id,
                          (try? moveItem(item.id, fromShelf: shelf.id, toShelf: rule.destinationShelfID)) == true
                    else { continue }
                    moves.append(AutomaticMove(
                        item: item,
                        shelfID: rule.destinationShelfID,
                        previousShelfID: shelf.id,
                        ruleID: rule.id,
                        date: date
                    ))
                }
            }
        }
        if let last = moves.last { lastAutomaticMove = last }
        return moves
    }

    public func canUndoAutomaticMove(at date: Date) -> Bool {
        guard let move = lastAutomaticMove else { return false }
        return date.timeIntervalSince(move.date) <= Self.undoWindow
    }

    /// Takes the last automatically filed item off its shelf, or puts an archived item back.
    @discardableResult
    public mutating func undoLastAutomaticMove(at date: Date) -> Bool {
        guard canUndoAutomaticMove(at: date), let move = lastAutomaticMove else { return false }
        if let previous = move.previousShelfID, layout.location(ofShelf: previous) != nil {
            _ = try? moveItem(move.item.id, fromShelf: move.shelfID, toShelf: previous)
        } else {
            removeItem(move.item.id, fromShelf: move.shelfID)
        }
        lastAutomaticMove = nil
        return true
    }

    // MARK: Import

    /// Replaces everything with an imported layout.
    public mutating func replaceLayout(with imported: ShelfLayout) {
        var imported = imported
        imported.normalize()
        layout = imported
        lastAutomaticMove = nil
    }

    /// Adds the Spaces from a `.shelfspace` template alongside the current ones, with fresh IDs so
    /// importing the same template twice never collides. Rules come along and are re-pointed.
    /// Returns the IDs of the new Spaces.
    @discardableResult
    public mutating func addSpaces(from template: ShelfLayout) -> [Space.ID] {
        var shelfIDs: [Shelf.ID: Shelf.ID] = [:]
        var spaceIDs: [Space.ID: Space.ID] = [:]
        var added: [Space] = []

        for var space in template.spaces {
            let newSpaceID = UUID()
            spaceIDs[space.id] = newSpaceID
            space.id = newSpaceID
            space.shelves = space.shelves.map { shelf in
                var shelf = shelf
                let newShelfID = UUID()
                shelfIDs[shelf.id] = newShelfID
                shelf.id = newShelfID
                shelf.items = shelf.items.map { item in
                    var item = item
                    item.id = UUID()
                    return item
                }
                return shelf
            }
            added.append(space)
        }

        layout.spaces.append(contentsOf: added)
        for var rule in template.rules {
            guard let destination = shelfIDs[rule.destinationShelfID] else { continue }
            rule.id = UUID()
            rule.destinationShelfID = destination
            rule.spaceID = rule.spaceID.flatMap { spaceIDs[$0] }
            layout.rules.append(rule)
        }
        return added.map(\.id)
    }

    // MARK: Helpers

    static func validatedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LibraryError.emptyName }
        return trimmed
    }
}

extension Array {
    /// Moves the elements at `offsets` to land before the element that was at `destination`.
    /// Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`, without depending on SwiftUI.
    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let valid = offsets.filter { indices.contains($0) }
        guard !valid.isEmpty else { return }
        let moving = valid.map { self[$0] }
        let insertionPoint = destination - valid.filter { $0 < destination }.count
        for index in valid.reversed() {
            remove(at: index)
        }
        insert(contentsOf: moving, at: Swift.min(Swift.max(insertionPoint, 0), endIndex))
    }
}
