import XCTest
@testable import ShelfKit

final class DragDropTests: XCTestCase {
    // MARK: Payloads

    func testPayloadDropsUnsafeSchemesAndRepeats() {
        let payload = DropPayload(urls: [
            URL(fileURLWithPath: "/Users/test/Desktop/../Desktop/Brief v3.docx"),
            URL(fileURLWithPath: "/Users/test/Desktop/Brief v3.docx"),
            URL(string: "https://shelfapp.com/changelog")!,
            URL(string: "javascript:alert(1)")!,
            URL(string: "mailto:hello@shelfapp.com")!,
        ])

        XCTAssertEqual(payload.urls.map(\.absoluteString), [
            "file:///Users/test/Desktop/Brief%20v3.docx",
            "https://shelfapp.com/changelog",
            "mailto:hello@shelfapp.com",
        ])
        XCTAssertEqual(payload.rejected, ["javascript:alert(1)"])
    }

    func testTextDropsBecomeLinks() {
        let payload = DropPayload.fromText("""
        https://example.com/kerning
        shelfapp.com/pricing
        ~/Desktop/notes.txt
        # a comment line

        just some words
        """)

        XCTAssertEqual(payload.urls.count, 3)
        XCTAssertEqual(payload.urls[1].absoluteString, "https://shelfapp.com/pricing")
        XCTAssertTrue(payload.urls[2].isFileURL)
        XCTAssertEqual(payload.urls[2].lastPathComponent, "notes.txt")
        XCTAssertEqual(payload.rejected, ["just some words"])
    }

    func testBookmarkFilesUnwrapToTheirLink() throws {
        let plist: [String: Any] = ["URL": "https://example.com/harbor-brief"]
        let webloc = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        XCTAssertEqual(DropPayload.bookmarkTarget(fileName: "Harbor brief.webloc", contents: webloc)?.absoluteString, "https://example.com/harbor-brief")

        let windows = Data("[InternetShortcut]\r\nURL=https://example.com/palette\r\n".utf8)
        XCTAssertEqual(DropPayload.bookmarkTarget(fileName: "Palette.URL", contents: windows)?.absoluteString, "https://example.com/palette")

        let unsafe = try PropertyListSerialization.data(fromPropertyList: ["URL": "javascript:void(0)"], format: .xml, options: 0)
        XCTAssertNil(DropPayload.bookmarkTarget(fileName: "x.webloc", contents: unsafe))
        XCTAssertNil(DropPayload.bookmarkTarget(fileName: "notes.txt", contents: Data()))
    }

    // MARK: Planning

    private func layoutWithItems() -> (ShelfLayout, ShelfItem, ShelfItem) {
        var layout = Fixtures.layout()
        let brief = Fixtures.item("Brief v3.docx")
        let logo = Fixtures.item("logo-final.svg")
        layout.spaces[0].shelves[0].add(brief)
        layout.spaces[0].shelves[0].add(logo)
        return (layout, brief, logo)
    }

    func testDraggingFromAnotherShelfInTheSpaceMoves() {
        let (layout, brief, _) = layoutWithItems()
        let plan = DropPlanner().plan(DropPayload(urls: [brief.url]), ontoShelf: Fixtures.archive.id, at: 0, in: layout)
        XCTAssertEqual(plan, .move(itemID: brief.id, fromShelf: Fixtures.inbox.id, toShelf: Fixtures.archive.id, at: 0))
    }

    func testOptionDragCopies() {
        let (layout, brief, _) = layoutWithItems()
        let plan = DropPlanner().plan(DropPayload(urls: [brief.url]), ontoShelf: Fixtures.archive.id, in: layout, copies: true)
        XCTAssertEqual(plan, .add([brief.url], toShelf: Fixtures.archive.id, at: nil))
    }

    func testReorderingOnTheSameShelf() {
        let (layout, brief, _) = layoutWithItems()
        let planner = DropPlanner()
        XCTAssertEqual(
            planner.plan(DropPayload(urls: [brief.url]), ontoShelf: Fixtures.inbox.id, at: 2, in: layout),
            .move(itemID: brief.id, fromShelf: Fixtures.inbox.id, toShelf: Fixtures.inbox.id, at: 2)
        )
        XCTAssertEqual(planner.plan(DropPayload(urls: [brief.url]), ontoShelf: Fixtures.inbox.id, at: 1, in: layout), .ignore, "dropping in place")
        XCTAssertEqual(planner.plan(DropPayload(urls: [brief.url]), ontoShelf: Fixtures.inbox.id, in: layout), .ignore)
    }

    func testItemsFromAnotherSpaceAreAddedNotMoved() {
        var (layout, _, _) = layoutWithItems()
        let palette = Fixtures.item("palette.ase")
        layout.spaces[1].shelves[0].add(palette)
        let plan = DropPlanner().plan(DropPayload(urls: [palette.url]), ontoShelf: Fixtures.inbox.id, in: layout)
        XCTAssertEqual(plan, .add([palette.url], toShelf: Fixtures.inbox.id, at: nil))
    }

    func testMultipleURLsAddOnlyWhatsNew() {
        let (layout, brief, _) = layoutWithItems()
        let fresh = Fixtures.file("q3-numbers.csv")
        let planner = DropPlanner()
        XCTAssertEqual(
            planner.plan(DropPayload(urls: [brief.url, fresh]), ontoShelf: Fixtures.inbox.id, at: 1, in: layout),
            .add([fresh], toShelf: Fixtures.inbox.id, at: 1)
        )
        XCTAssertEqual(planner.plan(DropPayload(), ontoShelf: Fixtures.inbox.id, in: layout), .ignore)
        XCTAssertEqual(planner.plan(DropPayload(urls: [fresh]), ontoShelf: UUID(), in: layout), .ignore)
    }

    // MARK: Grid geometry

    func testInsertionIndexFollowsThePointer() {
        let grid = ShelfGridMetrics(columns: 4, tileWidth: 76, tileHeight: 70, spacing: 12)
        XCTAssertEqual(grid.insertionIndex(x: 10, y: 10, itemCount: 8), 0)
        XCTAssertEqual(grid.insertionIndex(x: 60, y: 10, itemCount: 8), 1, "right half of the first tile")
        XCTAssertEqual(grid.insertionIndex(x: 100, y: 90, itemCount: 8), 5, "second row, second column")
        XCTAssertEqual(grid.insertionIndex(x: 900, y: 10, itemCount: 8), 4, "clamped to the last column")
        XCTAssertEqual(grid.insertionIndex(x: 10, y: 900, itemCount: 8), 8, "past the end")
        XCTAssertEqual(grid.insertionIndex(x: 10, y: 10, itemCount: 0), 0)
    }

    func testGridFitsItsWidth() {
        let grid = ShelfGridMetrics.fitting(width: 352)
        XCTAssertEqual(grid.columns, 4)
        XCTAssertEqual(ShelfGridMetrics.fitting(width: 20).columns, 1)
        XCTAssertEqual(grid.rows(forItemCount: 9), 3)
        XCTAssertEqual(grid.height(forItemCount: 5), 70 * 2 + 12)
        XCTAssertEqual(grid.height(forItemCount: 0), 0)
    }
}
