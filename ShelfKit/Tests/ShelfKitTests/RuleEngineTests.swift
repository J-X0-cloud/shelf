import XCTest
@testable import ShelfKit

final class RuleEngineTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-09-24T09:41:00Z")!
    private var engine: RuleEngine {
        let now = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return RuleEngine(now: { now }, calendar: calendar)
    }

    private func candidate(
        _ name: String,
        source: Rule.Source = .downloads,
        screenshot: Bool = false,
        lastUsedDaysAgo: Int? = nil
    ) -> FileCandidate {
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
        XCTAssertFalse(engine.matches(rule, candidate("pdf")), "a file named pdf has no extension")
    }

    func testSourceMustMatch() {
        let rule = Rule(source: .desktop, condition: .isScreenshot, destinationShelfID: Fixtures.inbox.id)
        XCTAssertTrue(engine.matches(rule, candidate("Screenshot 09.41.png", source: .desktop, screenshot: true)))
        XCTAssertFalse(engine.matches(rule, candidate("Screenshot 09.41.png", source: .downloads, screenshot: true)))
    }

    func testFolderSourcesCompareStandardizedPaths() {
        let rule = Rule(
            source: .folder(URL(fileURLWithPath: "/Users/test/Clients/../Clients/Harbor")),
            condition: .nameContains("menu"),
            destinationShelfID: Fixtures.brand.id
        )
        let file = FileCandidate(
            url: Fixtures.file("menu-proof.pdf", in: "/Users/test/Clients/Harbor"),
            source: .folder(URL(fileURLWithPath: "/Users/test/Clients/Harbor"))
        )
        XCTAssertTrue(engine.matches(rule, file))
    }

    func testNameContainsIgnoresCaseAndAccents() {
        let rule = Rule(source: .downloads, condition: .nameContains("harbor"), destinationShelfID: Fixtures.brand.id)
        XCTAssertTrue(engine.matches(rule, candidate("Harbor-menu-proof.pdf")))
        XCTAssertFalse(engine.matches(rule, candidate("brief-v3.docx")))

        let cafe = Rule(source: .downloads, condition: .nameContains("cafe"), destinationShelfID: Fixtures.brand.id)
        XCTAssertTrue(engine.matches(cafe, candidate("Café menu.pdf")))
    }

    func testUntouchedUsesCutoffAndSkipsUnknownDates() {
        let rule = Rule(source: .anyShelf, condition: .untouched(days: 30), destinationShelfID: Fixtures.inbox.id)
        XCTAssertTrue(engine.matches(rule, candidate("old.key", source: .anyShelf, lastUsedDaysAgo: 31)))
        XCTAssertFalse(engine.matches(rule, candidate("recent.key", source: .anyShelf, lastUsedDaysAgo: 29)))
        XCTAssertFalse(engine.matches(rule, candidate("unknown.key", source: .anyShelf)))
    }

    func testDisabledAndInvalidRulesNeverMatch() {
        let disabled = Rule(isEnabled: false, source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        XCTAssertFalse(engine.matches(disabled, candidate("invoice.pdf")))

        let blank = Rule(source: .downloads, condition: .nameContains("  "), destinationShelfID: Fixtures.paperwork.id)
        XCTAssertFalse(engine.matches(blank, candidate("invoice.pdf")))

        let dot = Rule(source: .downloads, condition: .extensionIs("."), destinationShelfID: Fixtures.paperwork.id)
        XCTAssertFalse(engine.matches(dot, candidate("invoice")))
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

    func testRulesFromOtherSpacesNeverRun() {
        let harborOnly = Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.brand.id, spaceID: Fixtures.harbor.id)
        XCTAssertNil(engine.firstMatch(in: [harborOnly], for: candidate("a.pdf"), activeSpaceID: Fixtures.studio.id))
    }

    func testPreviewIncludesDisabledRule() {
        let rule = Rule(isEnabled: false, source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id)
        let files = [candidate("a.pdf"), candidate("b.csv"), candidate("c.pdf")]
        XCTAssertEqual(engine.preview(rule, in: files).map(\.fileName), ["a.pdf", "c.pdf"])
    }

    func testWatchedSourcesAreUniqueEnabledFolderSources() {
        let rules = [
            Rule(source: .downloads, condition: .extensionIs("pdf"), destinationShelfID: Fixtures.paperwork.id),
            Rule(source: .downloads, condition: .nameContains("menu"), destinationShelfID: Fixtures.brand.id, spaceID: Fixtures.studio.id),
            Rule(source: .desktop, condition: .isScreenshot, destinationShelfID: Fixtures.inbox.id, spaceID: Fixtures.harbor.id),
            Rule(isEnabled: false, source: .folder(URL(fileURLWithPath: "/tmp/x")), condition: .isScreenshot, destinationShelfID: Fixtures.inbox.id),
            Rule(source: .anyShelf, condition: .untouched(days: 30), destinationShelfID: Fixtures.archive.id),
        ]
        XCTAssertEqual(engine.watchedSources(for: rules, activeSpaceID: Fixtures.studio.id), [.downloads])
        XCTAssertEqual(engine.watchedSources(for: rules, activeSpaceID: Fixtures.harbor.id), [.desktop, .downloads])
    }

    func testRuleSummaryReadsAsASentence() {
        let rule = Rule(source: .downloads, condition: .extensionIs(" .PDF"), destinationShelfID: Fixtures.paperwork.id)
        XCTAssertEqual(rule.summary, "When a file in Downloads name ends with .pdf")
        XCTAssertEqual(Rule.Condition.untouched(days: 1).displayText, "untouched for 1 day")
    }

    func testScreenshotNamesAreRecognised() {
        XCTAssertTrue(ScreenshotName.matches("Screenshot 2026-09-24 at 09.41.12.png"))
        XCTAssertTrue(ScreenshotName.matches("Screen Shot 2019-02-01 at 10.00.00.png"))
        XCTAssertTrue(ScreenshotName.matches("Screen Recording 2026-09-24 at 09.41.mov"))
        XCTAssertFalse(ScreenshotName.matches("Screenshot notes.txt"))
        XCTAssertFalse(ScreenshotName.matches("hero-crop.png"))
    }

    func testFileSystemInspectorReadsRealFiles() throws {
        let folder = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let shot = folder.appendingPathComponent("Screenshot 2026-09-24 at 09.41.12.png")
        try Data([0x89, 0x50]).write(to: shot)

        let candidate = FileSystemInspector().inspect(shot, source: .desktop)
        XCTAssertTrue(candidate.isScreenshot)
        XCTAssertNotNil(candidate.lastUsed)
        XCTAssertEqual(candidate.source, .desktop)
    }
}
