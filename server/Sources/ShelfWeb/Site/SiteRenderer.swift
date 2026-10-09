import Foundation
import ShelfKit

/// Builds every page of the product site once at startup. Pages are HTML files in
/// `site/templates/pages`, wrapped in `layout.html`, with shared pieces in `partials/`. Facts that
/// change with each release (version, download link, size, price) come from Swift, so the site,
/// the changelog and the appcast can never disagree.
public struct SiteRenderer: Sendable {
    public struct Page: Sendable, Equatable {
        /// URL path the page is served at, e.g. "/features".
        public var path: String
        public var title: String
        public var description: String
        public var html: String
    }

    public static let defaultTitle = "Shelf — Menu-bar shelves and Spaces for a tidy Mac"
    public static let defaultDescription =
        "Shelf is a native macOS menu-bar app that organizes your Dock and desktop into shelves and Spaces. 14-day free trial, $19 once."

    public let pages: [String: Page]
    public let notFound: Page

    public enum LoadError: Error, CustomStringConvertible {
        case missingFolder(String)
        case missingLayout(String)
        case missingNotFoundPage

        public var description: String {
            switch self {
            case let .missingFolder(path): "No templates folder at \(path). Set SITE_ROOT to the repository's site/ folder."
            case let .missingLayout(path): "No layout.html in \(path)"
            case .missingNotFoundPage: "pages/404.html is missing"
            }
        }
    }

    /// Reads and renders everything under `<siteRoot>/templates`.
    public init(siteRoot: String, configuration: SiteConfiguration, releases: [Release] = Releases.all) throws {
        let fileManager = FileManager.default
        let templates = URL(fileURLWithPath: siteRoot).appendingPathComponent("templates", isDirectory: true)
        guard fileManager.fileExists(atPath: templates.path) else { throw LoadError.missingFolder(templates.path) }

        let layoutURL = templates.appendingPathComponent("layout.html")
        guard fileManager.fileExists(atPath: layoutURL.path) else { throw LoadError.missingLayout(templates.path) }
        let layout = try Template(name: "layout.html", source: String(contentsOf: layoutURL, encoding: .utf8))

        var partials: [String: Template] = [:]
        for url in try SiteRenderer.htmlFiles(in: templates.appendingPathComponent("partials")) {
            let name = url.deletingPathExtension().lastPathComponent
            partials[name] = try Template(name: "partials/\(url.lastPathComponent)", source: String(contentsOf: url, encoding: .utf8))
        }

        let values = SiteRenderer.values(configuration: configuration, releases: releases)
        var pages: [String: Page] = [:]
        var notFound: Page?

        for url in try SiteRenderer.htmlFiles(in: templates.appendingPathComponent("pages")) {
            let slug = url.deletingPathExtension().lastPathComponent
            let source = try String(contentsOf: url, encoding: .utf8)
            let (meta, body) = SiteRenderer.frontMatter(source)
            let path = slug == "index" ? "/" : "/\(slug)"
            let title = meta["title"].map { "\($0) — Shelf for macOS" } ?? SiteRenderer.defaultTitle
            let description = meta["description"] ?? SiteRenderer.defaultDescription

            var context = Template.Context(values: values, partials: partials, currentPath: path)
            context.values["page.path"] = path
            context.values["page.title"] = title
            context.values["page.description"] = description
            context.values["page.url"] = configuration.siteURL + (path == "/" ? "" : path)
            context.values["content"] = try Template(name: "pages/\(url.lastPathComponent)", source: body).render(context)

            let page = Page(path: path, title: title, description: description, html: try layout.render(context))
            if slug == "404" {
                notFound = page
            } else {
                pages[path] = page
            }
        }

        guard let notFound else { throw LoadError.missingNotFoundPage }
        self.pages = pages
        self.notFound = notFound
    }

    public func page(at path: String) -> Page? {
        let trimmed = path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
        return pages[trimmed]
    }

    // MARK: Values

    /// The release- and price-dependent facts every template can use.
    static func values(configuration: SiteConfiguration, releases: [Release]) -> [String: String] {
        let latest = releases[0]
        return [
            "site.url": configuration.siteURL,
            "release.version": latest.version.description,
            "release.minor": latest.version.minorString,
            "release.date": latest.formattedDate,
            "download.href": latest.downloadURL(base: configuration.downloadBaseURL),
            "download.label": "Download Shelf \(latest.version.minorString)",
            "download.size": latest.formattedSize ?? "",
            "price.personal": Plan.personal.formattedPrice,
            "price.family": Plan.family.formattedPrice,
            "price.team": Plan.team.formattedPrice,
            "trial.days": "14",
            "refund.days": "30",
            "support.email": "hello@shelfapp.com",
            "requirements.macos": "macOS 13 Ventura or later",
            "requirements.macos.short": "macOS 13 or later",
            "requirements.architectures": "Universal app for Apple silicon and Intel",
            "releases": ReleaseNotesHTML.render(releases),
        ]
    }

    // MARK: Files

    static func htmlFiles(in folder: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "html" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Splits an optional leading comment of `key: value` lines from the page body:
    ///
    ///     <!--
    ///     title: Features
    ///     description: A tour of everything Shelf does.
    ///     -->
    static func frontMatter(_ source: String) -> (meta: [String: String], body: String) {
        let trimmed = source.drop { $0.isWhitespace }
        guard trimmed.hasPrefix("<!--"), let end = trimmed.range(of: "-->") else { return ([:], source) }
        var meta: [String: String] = [:]
        for line in trimmed[trimmed.index(trimmed.startIndex, offsetBy: 4) ..< end.lowerBound].split(whereSeparator: \.isNewline) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, !value.isEmpty { meta[key] = value }
        }
        let body = trimmed[end.upperBound...].drop { $0 == "\n" || $0 == "\r" }
        return (meta, String(body))
    }
}

/// The changelog's release list, built from the same data as the appcast.
public enum ReleaseNotesHTML {
    public static func render(_ releases: [Release]) -> String {
        releases.map(article).joined(separator: "\n")
    }

    static func article(_ release: Release) -> String {
        var body: [String] = []
        if let title = release.title { body.append("<h2>\(HTML.escape(title))</h2>") }
        if let summary = release.summary { body.append("<p>\(HTML.escape(summary))</p>") }
        let changes = release.changes.map { change in
            let kind = change.kind.rawValue
            return #"<li><span class="tag tag-\#(kind.lowercased())">\#(kind)</span><span>\#(HTML.escape(change.text))</span></li>"#
        }
        body.append("<ul>\(changes.joined())</ul>")

        return """
        <article class="rel" id="\(release.anchor)">
          <div class="rel-m"><span class="ver">\(release.version)</span><time datetime="\(release.date)">\(release.formattedDate)</time></div>
          <div class="rel-b">\(body.joined())</div>
        </article>
        """
    }
}
