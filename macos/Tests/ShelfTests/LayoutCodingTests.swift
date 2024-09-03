import XCTest
@testable import Shelf

final class LayoutCodingTests: XCTestCase {
    func testLayoutRoundTripsThroughShelfspaceEncoding() throws {
        var layout = Fixtures.layout(rules: [
            Rule(source: .folder(URL(fileURLWithPath: "/Users/test/Clients")), condition: .nameContains("harbor"), destinationShelfID: Fixtures.brand.id),
            Rule(isEnabled: false, source: .anyShelf, condition: .untouched(days: 30), destinationShelfID: Fixtures.inbox.id),
        ])
        layout.spaces[0].shelves[0].add(ShelfItem(url: URL(string: "https://example.com/kerning")!, addedAt: Date(timeIntervalSince1970: 1_790_000_000)))

        let data = try LayoutCoder.encoder.encode(layout)
        let decoded = try LayoutCoder.decoder.decode(ShelfLayout.self, from: data)

        XCTAssertEqual(decoded, layout)
        XCTAssertEqual(decoded.version, ShelfLayout.currentVersion)
        XCTAssertEqual(decoded.spaces[0].shelves[0].items.first?.kind, .link)
    }

    func testItemKindIsInferredFromURL() {
        XCTAssertEqual(ShelfItem.inferKind(for: URL(fileURLWithPath: "/Applications/Notes.app")), .app)
        XCTAssertEqual(ShelfItem.inferKind(for: URL(fileURLWithPath: "/Users/test/Exports/", isDirectory: true)), .folder)
        XCTAssertEqual(ShelfItem.inferKind(for: URL(fileURLWithPath: "/Users/test/contract.pages")), .file)
        XCTAssertEqual(ShelfItem.displayName(for: URL(fileURLWithPath: "/Applications/Notes.app")), "Notes")
    }

    func testStarterLayoutRulesPointAtExistingShelves() {
        let layout = ShelfLayout.starter()
        for rule in layout.rules {
            XCTAssertNotNil(layout.location(ofShelf: rule.destinationShelfID), "\(rule.condition.displayText) has no shelf")
        }
    }
}
