import Foundation

/// What a drop onto a shelf should do.
public enum DropPlan: Equatable, Sendable {
    /// Nothing to do: the payload was empty or everything is already on the target shelf.
    case ignore
    /// Put new items on the shelf at `index` (the end when `nil`).
    case add([URL], toShelf: Shelf.ID, at: Int?)
    /// An item dragged from one shelf to another (or to a new spot on the same shelf).
    case move(itemID: ShelfItem.ID, fromShelf: Shelf.ID, toShelf: Shelf.ID, at: Int?)
}

/// Decides what a drop means. Dragging a tile from one shelf onto another moves it rather than
/// leaving a duplicate behind; dragging in from Finder or a browser adds new items. Holding ⌥
/// (`copies`) keeps the original where it was, as in Finder.
public struct DropPlanner: Sendable {
    public init() {}

    public func plan(
        _ payload: DropPayload,
        ontoShelf targetID: Shelf.ID,
        at index: Int? = nil,
        in layout: ShelfLayout,
        copies: Bool = false
    ) -> DropPlan {
        guard let target = layout.shelf(id: targetID), !payload.isEmpty else { return .ignore }

        // A single URL that already lives on a shelf in the same Space is an internal drag: move it.
        if !copies, payload.urls.count == 1, let url = payload.urls.first,
           let space = layout.location(ofShelf: targetID).map({ layout.spaces[$0.space] }),
           let source = space.shelf(holding: url),
           let item = source.items.first(where: { $0.refersToSameTarget(as: url) }) {
            if source.id == targetID {
                guard let from = target.index(of: url), let index, index != from, index != from + 1 else { return .ignore }
                return .move(itemID: item.id, fromShelf: source.id, toShelf: targetID, at: index)
            }
            return .move(itemID: item.id, fromShelf: source.id, toShelf: targetID, at: index)
        }

        let fresh = payload.urls.filter { !target.contains($0) }
        guard !fresh.isEmpty else { return .ignore }
        return .add(fresh, toShelf: targetID, at: index)
    }
}

/// The grid a shelf lays its tiles out in, used to turn a drop location into an insertion index
/// and to size panels. Measured in points, origin at the top-left of the grid.
public struct ShelfGridMetrics: Equatable, Sendable {
    public var columns: Int
    public var tileWidth: Double
    public var tileHeight: Double
    public var spacing: Double

    public init(columns: Int = 4, tileWidth: Double = 76, tileHeight: Double = 70, spacing: Double = 12) {
        self.columns = max(columns, 1)
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.spacing = spacing
    }

    /// The column count that fits a panel of the given content width.
    public static func fitting(width: Double, tileWidth: Double = 76, spacing: Double = 12) -> ShelfGridMetrics {
        let columns = Int(((width + spacing) / (tileWidth + spacing)).rounded(.down))
        return ShelfGridMetrics(columns: max(columns, 1), tileWidth: tileWidth, spacing: spacing)
    }

    public func rows(forItemCount count: Int) -> Int {
        count == 0 ? 0 : (count + columns - 1) / columns
    }

    /// Height of the grid for `count` items.
    public func height(forItemCount count: Int) -> Double {
        let rows = rows(forItemCount: count)
        return rows == 0 ? 0 : Double(rows) * tileHeight + Double(rows - 1) * spacing
    }

    /// Where a dropped item should go when released at (x, y): before the tile under the pointer,
    /// or after it when the pointer is on the tile's right half. Clamped to `0...count`.
    public func insertionIndex(x: Double, y: Double, itemCount count: Int) -> Int {
        guard count > 0 else { return 0 }
        let row = max(0, Int((y + spacing / 2) / (tileHeight + spacing)))
        let cellWidth = tileWidth + spacing
        let column = min(max(0, Int(x / cellWidth)), columns - 1)
        let withinTile = x - Double(column) * cellWidth
        let index = row * columns + column + (withinTile > tileWidth / 2 ? 1 : 0)
        return min(max(index, 0), count)
    }
}
