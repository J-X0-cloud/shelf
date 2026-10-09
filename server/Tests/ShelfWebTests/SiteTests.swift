import Foundation
import ShelfKit
import XCTest
@testable import ShelfWeb

/// The repository's real `site/` folder, so these tests catch template mistakes before deploys do.
enum SiteFolder {
    static var path: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ShelfWebTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // server
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("site")
            .path
    }

    static func configuration(_ change: (inout SiteConfiguration) -> Void = { _ in }) -> SiteConfiguration {
        var configuration = SiteConfiguration(siteURL: "https://shelf.test/", downloadBaseURL: "https://dl.shelf.test", siteRoot: path)
        change(&configuration)
        return configuration
    }
}

final class TemplateTests: XCTestCase {
    func testValuesAreEscapedUnlessTripleBraced() throws {
        let template = try Template(name: "t", source: "<p>{{name}}</p>{{{html}}}")
        let output = try template.render(.init(values: ["name": "Ben & <Jerry>", "html": "<b>bold</b>"]))
        XCTAssertEqual(output, "<p>Ben &amp; &lt;Jerry&gt;</p><b>bold</b>")
    }

    func testPartialsShareTheContext() throws {
        let partial = try Template(name: "p", source: "<em>{{price}}</em>")
        let page = try Template(name: "page", source: "Only {{> price}} once")
        XCTAssertEqual(try page.render(.init(values: ["price": "$19"], partials: ["price": partial])), "Only <em>$19</em> once")
    }

    func testIconsAndCurrentPath() throws {
        let template = try Template(name: "t", source: #"<a href="/pricing"{{current /pricing}}>{{icon check 18 2.2}}</a>"#)
        let onPricing = try template.render(.init(currentPath: "/pricing"))
        XCTAssertTrue(onPricing.hasPrefix(#"<a href="/pricing" aria-current="page"><svg width="18" height="18""#))
        XCTAssertTrue(onPricing.contains(#"stroke-width="2.2""#))
        XCTAssertFalse(try template.render(.init(currentPath: "/")).contains("aria-current"))
        XCTAssertTrue(Icon.svg(.down).contains(#"width="20" height="20""#))
        XCTAssertTrue(Icon.svg(.down).contains(#"stroke-width="1.7""#))
    }

    func testMistakesAreErrorsNotBlanks() {
        XCTAssertThrowsError(try Template(name: "t", source: "a {{oops")) {
            XCTAssertEqual($0 as? Template.Error, .unclosedTag(name: "t", line: 1))
        }
        XCTAssertThrowsError(try Template(name: "t", source: "\n\n{{ }}")) {
            XCTAssertEqual($0 as? Template.Error, .emptyTag(name: "t", line: 3))
        }
        XCTAssertThrowsError(try Template(name: "t", source: "{{icon kettle}}")) {
            XCTAssertEqual($0 as? Template.Error, .unknownIcon("kettle", template: "t"))
        }
        XCTAssertThrowsError(try Template(name: "t", source: "{{icon check big}}"))
        XCTAssertThrowsError(try Template(name: "t", source: "{{missing}}").render(.init())) {
            XCTAssertEqual($0 as? Template.Error, .missingValue("missing", template: "t"))
        }
        XCTAssertThrowsError(try Template(name: "t", source: "{{> nowhere}}").render(.init()))
    }

    func testPartialsCannotIncludeThemselves() throws {
        let loop = try Template(name: "loop", source: "again {{> loop}}")
        XCTAssertThrowsError(try loop.render(.init(partials: ["loop": loop]))) {
            XCTAssertEqual($0 as? Template.Error, .recursivePartial("loop"))
        }
    }

    func testFrontMatter() {
        let (meta, body) = SiteRenderer.frontMatter("<!--\ntitle: Pricing\ndescription: Pay once: tidy forever.\n-->\n<h1>Hi</h1>")
        XCTAssertEqual(meta, ["title": "Pricing", "description": "Pay once: tidy forever."])
        XCTAssertEqual(body, "<h1>Hi</h1>")
        XCTAssertEqual(SiteRenderer.frontMatter("<h1>No meta</h1>").body, "<h1>No meta</h1>")
    }
}

final class SiteRendererTests: XCTestCase {
    private var renderer: SiteRenderer!

    override func setUpWithError() throws {
        renderer = try SiteRenderer(siteRoot: SiteFolder.path, configuration: SiteFolder.configuration())
    }

    func testEveryPageRenders() throws {
        XCTAssertEqual(renderer.pages.keys.sorted(), ["/", "/changelog", "/features", "/pricing", "/support"])
        for page in renderer.pages.values {
            XCTAssertTrue(page.html.hasPrefix("<!doctype html>"), page.path)
            XCTAssertTrue(page.html.contains(#"<main id="main">"#), page.path)
            XCTAssertFalse(page.html.contains("{{"), "\(page.path) has an unrendered tag")
            XCTAssertTrue(page.html.contains(#"id="download""#), "\(page.path) is missing the download section")
        }
    }

    func testTitlesAndCanonicalLinks() throws {
        let features = try XCTUnwrap(renderer.page(at: "/features/"))
        XCTAssertEqual(features.title, "Features — Shelf for macOS")
        XCTAssertTrue(features.html.contains(#"<link rel="canonical" href="https://shelf.test/features" />"#))
        XCTAssertEqual(renderer.page(at: "/")?.title, SiteRenderer.defaultTitle)
        XCTAssertNil(renderer.page(at: "/404"), "the not-found page has no route of its own")
    }

    func testNavigationMarksTheCurrentPage() throws {
        let pricing = try XCTUnwrap(renderer.page(at: "/pricing")).html
        XCTAssertTrue(pricing.contains(#"<a href="/pricing" aria-current="page">Pricing</a"#))
        XCTAssertFalse(pricing.contains(#"<a href="/features" aria-current="page">"#))
    }

    func testReleaseFactsComeFromTheChangelogData() throws {
        let latest = Releases.latest
        let home = try XCTUnwrap(renderer.page(at: "/")).html
        XCTAssertTrue(home.contains("https://dl.shelf.test/Shelf-\(latest.version).dmg"))
        XCTAssertTrue(home.contains("Download Shelf \(latest.version.minorString)"))
        XCTAssertTrue(home.contains("Shelf \(latest.version) · \(latest.formattedDate)"))
        XCTAssertTrue(home.contains(latest.formattedSize!))

        let changelog = try XCTUnwrap(renderer.page(at: "/changelog")).html
        for release in Releases.all {
            XCTAssertTrue(changelog.contains(#"id="\#(release.anchor)""#), release.version.description)
        }
        XCTAssertTrue(changelog.contains("Current version <b>\(latest.version)</b>"))
    }

    func testReleaseNotesMarkup() {
        let html = ReleaseNotesHTML.article(Releases.all[1])
        XCTAssertTrue(html.contains(#"<article class="rel" id="v2-4-0">"#))
        XCTAssertTrue(html.contains("<h2>Rules for every Space</h2>"))
        XCTAssertTrue(html.contains(#"<time datetime="2026-09-15">Sep 15, 2026</time>"#))
        XCTAssertTrue(html.contains(#"<span class="tag tag-improved">Improved</span>"#))
        XCTAssertTrue(html.contains("client&#39;s downloads"))
    }

    func testMissingFoldersAreReported() {
        XCTAssertThrowsError(try SiteRenderer(siteRoot: "/nonexistent", configuration: SiteConfiguration()))
    }
}
