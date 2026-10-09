import Foundation

/// Builds the Sparkle appcast the macOS app polls for updates (SUFeedURL). Only releases with a
/// known download size are published; older builds stay in the changelog but not in the feed.
public struct Appcast: Sendable {
    public var siteURL: String
    public var downloadBaseURL: String
    public var minimumSystemVersion = "13.0"

    public init(siteURL: String, downloadBaseURL: String) {
        self.siteURL = siteURL
        self.downloadBaseURL = downloadBaseURL
    }

    public func render(_ releases: [Release]) -> String {
        let items = releases.filter { $0.size != nil }.map(item).joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <title>Shelf</title>
            <link>\(HTML.escape(siteURL))/appcast.xml</link>
            <language>en</language>
        \(items)
          </channel>
        </rss>

        """
    }

    private func item(_ release: Release) -> String {
        // Releases go out at 16:00 UTC on their release day.
        let published = release.day.map { ReleaseFormat.rss.string(from: $0.addingTimeInterval(16 * 3600)) } ?? ""
        let version = release.version.description
        return """
            <item>
              <title>Shelf \(version)</title>
              <pubDate>\(published)</pubDate>
              <sparkle:version>\(version)</sparkle:version>
              <sparkle:shortVersionString>\(version)</sparkle:shortVersionString>
              <sparkle:minimumSystemVersion>\(minimumSystemVersion)</sparkle:minimumSystemVersion>
              <sparkle:releaseNotesLink>\(HTML.escape(siteURL))/changelog#\(release.anchor)</sparkle:releaseNotesLink>
              <description><![CDATA[\(notes(release))]]></description>
              <enclosure url="\(HTML.escape(release.downloadURL(base: downloadBaseURL)))" length="\(release.size ?? 0)" type="application/octet-stream" />
            </item>
        """
    }

    /// The release notes Sparkle shows in its update window.
    func notes(_ release: Release) -> String {
        let intro = release.summary.map { "<p>\(HTML.escape($0))</p>" } ?? ""
        let items = release.changes.map { "<li><strong>\($0.kind.rawValue)</strong> \(HTML.escape($0.text))</li>" }.joined()
        // A literal "]]>" in the notes would end the CDATA section early.
        return "\(intro)<ul>\(items)</ul>".replacingOccurrences(of: "]]>", with: "]]&gt;")
    }
}

/// Escaping for text placed in HTML and XML.
public enum HTML {
    public static func escape(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": escaped += "&amp;"
            case "<": escaped += "&lt;"
            case ">": escaped += "&gt;"
            case "\"": escaped += "&quot;"
            case "'": escaped += "&#39;"
            default: escaped.append(character)
            }
        }
        return escaped
    }
}
