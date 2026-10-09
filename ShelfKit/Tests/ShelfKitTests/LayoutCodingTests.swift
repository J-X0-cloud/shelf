import XCTest
@testable import ShelfKit

final class LayoutCodingTests: XCTestCase {
    func testLayoutRoundTripsThroughShelfspaceEncoding() throws {
        var layout = Fixtures.layout(rules: [
            Rule(source: .folder(URL(fileURLWithPath: "/Users/test/Clients")), condition: .nameContains("harbor"), destinationShelfID: Fixtures.brand.id),
            Rule(isEnabled: false, source: .anyShelf, condition: .untouched(days: 30), destinationShelfID: Fixtures.inbox.id),
        ])
        layout.spaces[0].shelves[0].add(ShelfItem(url: URL(string: "https://example.com/kerning")!, addedAt: Date(timeIntervalSince1970: 1_790_000_000)))

        let decoded = try LayoutCoder.decode(LayoutCoder.encode(layout))

        XCTAssertEqual(decoded, layout)
        XCTAssertEqual(decoded.version, ShelfLayout.currentVersion)
        XCTAssertEqual(decoded.spaces[0].shelves[0].items.first?.kind, .link)
    }

    func testItemKindIsInferredFromURL() {
        XCTAssertEqual(ShelfItem.inferKind(for: URL(fileURLWithPath: "/Applications/Notes.app")), .app)
        XCTAssertEqual(ShelfItem.inferKind(for: URL(fileURLWithPath: "/Users/test/Exports/", isDirectory: true)), .folder)
        XCTAssertEqual(ShelfItem.inferKind(for: URL(fileURLWithPath: "/Users/test/contract.pages")), .file)
        XCTAssertEqual(ShelfItem.inferKind(for: URL(string: "https://shelfapp.com")!), .link)
        XCTAssertEqual(ShelfItem.displayName(for: URL(fileURLWithPath: "/Applications/Notes.app")), "Notes")
        XCTAssertEqual(ShelfItem.displayName(for: URL(string: "https://shelfapp.com/changelog")!), "shelfapp.com")
    }

    func testBadgesAreShortUppercaseExtensions() {
        XCTAssertEqual(Fixtures.item("contract.pages").badge, "PAG")
        XCTAssertEqual(Fixtures.item("invoice.pdf").badge, "PDF")
        XCTAssertNil(Fixtures.item("README").badge)
        XCTAssertNil(ShelfItem(url: URL(fileURLWithPath: "/Applications/Notes.app")).badge)
    }

    func testStarterLayoutRulesPointAtExistingShelves() {
        let layout = ShelfLayout.starter()
        XCTAssertTrue(layout.orphanedRules.isEmpty)
        XCTAssertEqual(layout.activeSpace?.name, "Studio")
    }

    func testVersionOneLayoutsMigrate() throws {
        let shelfID = UUID()
        let spaceID = UUID()
        let json = """
        {
          "spaces": [
            {
              "id": "\(spaceID)",
              "name": "Studio",
              "colorHex": "#E4572E",
              "focusModes": [],
              "shelves": [{ "id": "\(shelfID)", "name": "Inbox", "colorHex": "#E4572E", "items": [] }]
            }
          ],
          "rules": [
            {
              "id": "\(UUID())",
              "isEnabled": true,
              "source": { "downloads": {} },
              "condition": { "extensionIs": { "_0": "pdf" } },
              "destinationShelfID": "\(shelfID)"
            }
          ]
        }
        """

        let layout = try LayoutCoder.decode(Data(json.utf8))

        XCTAssertEqual(layout.version, ShelfLayout.currentVersion)
        XCTAssertTrue(layout.runsRulesAutomatically)
        XCTAssertEqual(layout.activeSpaceID, spaceID, "a missing active Space falls back to the first one")
        XCTAssertEqual(layout.spaces[0].shelves[0].placement, .floating)
        XCTAssertEqual(layout.spaces[0].shelves[0].sortOrder, .manual)
        XCTAssertNil(layout.rules[0].spaceID)
        XCTAssertEqual(layout.rules[0].condition, .extensionIs("pdf"))
    }

    func testNewerFormatsAreRefused() {
        let json = #"{ "version": 99, "spaces": [] }"#
        XCTAssertThrowsError(try LayoutCoder.decode(Data(json.utf8))) { error in
            XCTAssertEqual(error as? LayoutError, .unsupportedVersion(99))
        }
    }

    func testDuplicateShelvesAreRefused() throws {
        var layout = Fixtures.layout()
        layout.spaces[1].shelves.append(Fixtures.inbox)
        XCTAssertThrowsError(try LayoutCoder.decode(LayoutCoder.encode(layout))) { error in
            XCTAssertEqual(error as? LayoutError, .duplicateShelf(Fixtures.inbox.id))
        }
    }

    func testStaleActiveSpaceIsRepaired() throws {
        var layout = Fixtures.layout()
        layout.activeSpaceID = UUID()
        let decoded = try LayoutCoder.decode(LayoutCoder.encode(layout))
        XCTAssertEqual(decoded.activeSpaceID, Fixtures.studio.id)
    }

    func testExportsDropPersonalData() throws {
        var layout = Fixtures.layout()
        var item = Fixtures.item("Brief v3.docx")
        item.bookmark = Data([1, 2, 3])
        item.lastOpenedAt = Date()
        layout.spaces[0].shelves[0].add(item)
        layout.spaces[0].shelves[0].displayUUID = "37D8832A-2D66-02CA-B9F7-8F30A301B230"

        let exported = try LayoutCoder.decode(LayoutCoder.exportData(for: layout))
        let shelf = exported.spaces[0].shelves[0]

        XCTAssertNil(shelf.items[0].bookmark)
        XCTAssertNil(shelf.items[0].lastOpenedAt)
        XCTAssertNil(shelf.displayUUID)
        XCTAssertEqual(shelf.items[0].url, item.url)
    }

    func testFilePersistenceKeepsABackupOfThePreviousSave() throws {
        let folder = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let persistence = FileLayoutPersistence(fileURL: folder.appendingPathComponent("Shelf/Layout.json"))

        XCTAssertNil(try persistence.load())

        let first = Fixtures.layout()
        try persistence.save(first)
        var second = first
        second.activeSpaceID = Fixtures.harbor.id
        try persistence.save(second)

        XCTAssertEqual(try persistence.load(), second)
        XCTAssertEqual(try persistence.loadBackup(), first)
    }
}
