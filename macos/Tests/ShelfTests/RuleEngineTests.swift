import XCTest
@testable import Shelf

final class RuleEngineTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-09-24T09:41:00Z")!
    private var engine: RuleEngine { RuleEngine(now: { self.now }) }

    private func candidate(_ name: String, source: Rule.Source = .downloads, screenshot: Bool = false, lastUsedDaysAgo: Int? = nil) -> FileCandidate {
        FileCandidate(
            url: Fixtures.file(name),
            source: source,
            isScreenshot: screenshot,
            lastUsed: lastUsedDaysAgo.map { now.addingTimeInterval(-Double($0) * 86_400) }
        )
    }

    func testExtensionMatchIsCaseInsensitiveAndIgnoresLeadingDot() {
        let rule = Rule(source: .downloads, condition: .extensionIs(".pdf"), destinationShelfID: Fixtures.paperwork.id)
        XCTAssertTrue(engine.matches(rule, candidate("invoice-0932.PDF")))
        XCTAssertFalse(engine.matches(rule, candidate("q3-numbers.csv")))
    }

    func testSourceMustMatch() {
        let rule = Rule(source: .desktop, condition: .isScreenshot, destinationShelfID: Fixtures.inbox.id)
        XCTAssertTrue(engine.matches(rule, candidate("Screenshot 09.41.png", source: .desktop, screenshot: true)))
        XCTAssertFalse(engine.matches(rule, candidate("Screenshot 09.41.png", source: .downloads, screenshot: true)))
    }

    func testNameContains() {
        let rule = Rule(source: .downloads, condition: .nameContains("harbor"), destinationShelfID: Fixtures.brand.id)
        XCTAssertTrue(engine.matches(rule, candidate("Harbor-menu-proof.pdf")))
        XCTAssertFalse(engine.matches(rule, candidate("brief-v3.docx")))
    }

    func testUntouchedUsesCutoffAndSkipsUnknownDates() {
        let rule = Rule(source: .anyShelf, condition: .untouched(days: 30), destinationShelfID: Fixtures.inbox.id)
        XCTAssertTrue(engine.matches(rule, candidate("old.key", source: .anyShelf, lastUsedDaysAgo: 31)))
        XCTAssertFalse(engine.matches(rule, candidate("recent.key", source: .anyShelf, lastUsedDaysAgo: 29)))
        XCTAssertFalse(engine.matches(rule, candidate("unknown.key", source: .anyShelf)))
    }

    func testDisabledRulesNeverMatch() {
        let rule = Rule(isEnabled: false, source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        XCTAssertFalse(engine.matches(rule, candidate("invoice.pdf")))
    }

    func testActiveSpaceRulesWinOverGlobalRules() {
        let global = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        let harborOnly = Rule(
            source: .downloads,
            condition: .nameContains("harbor"),
            destinationShelfID: Fixtures.brand.id,
            spaceID: Fixtures.harbor.id
        )
        let rules = [global, harborOnly]
        let file = candidate("harbor-invoice.pdf")

        XCTAssertEqual(engine.firstMatch(in: rules, for: file, activeSpaceID: Fixtures.harbor.id)?.id, harborOnly.id)
        XCTAssertEqual(engine.firstMatch(in: rules, for: file, activeSpaceID: Fixtures.studio.id)?.id, global.id)
    }

    func testPreviewIncludesDisabledRule() {
        let rule = Rule(isEnabled: false, source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        let files = [candidate("a.pdf"), candidate("b.csv"), candidate("c.pdf")]
        XCTAssertEqual(engine.preview(rule, in: files).map(\.fileName), ["a.pdf", "c.pdf"])
    }
}
