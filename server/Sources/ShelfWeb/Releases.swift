import Foundation
import ShelfKit

/// One line of release notes.
public struct Change: Hashable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case new = "New"
        case improved = "Improved"
        case fixed = "Fixed"
    }

    public var kind: Kind
    public var text: String

    public init(_ kind: Kind, _ text: String) {
        self.kind = kind
        self.text = text
    }
}

/// A shipped version of the app. The same list feeds the changelog page and the Sparkle appcast.
public struct Release: Hashable, Sendable {
    public var version: AppVersion
    /// The day it shipped, as an ISO date (YYYY-MM-DD).
    public var date: String
    public var title: String?
    public var summary: String?
    public var changes: [Change]
    /// Download size in bytes of the notarized .dmg. Releases without one stay out of the appcast.
    public var size: Int?

    public init(_ version: String, date: String, title: String? = nil, summary: String? = nil, size: Int? = nil, changes: [Change]) {
        guard let parsed = AppVersion(version) else { preconditionFailure("Invalid release version \(version)") }
        self.version = parsed
        self.date = date
        self.title = title
        self.summary = summary
        self.size = size
        self.changes = changes
    }

    /// Anchor used on the changelog page, e.g. "v2-4-1".
    public var anchor: String {
        "v" + version.description.replacingOccurrences(of: ".", with: "-")
    }

    /// Midnight UTC on the release day.
    public var day: Date? {
        ReleaseFormat.isoDay.date(from: date)
    }

    /// "Sep 22, 2026".
    public var formattedDate: String {
        day.map(ReleaseFormat.display.string(from:)) ?? date
    }

    public func downloadURL(base: String) -> String {
        "\(base)/Shelf-\(version).dmg"
    }

    /// "11.4 MB" (decimal megabytes, as Finder reports them).
    public var formattedSize: String? {
        size.map { String(format: "%.1f MB", Double($0) / 1_000_000) }
    }
}

enum ReleaseFormat {
    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let display: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    /// RFC 822 dates for RSS, e.g. "Tue, 22 Sep 2026 16:00:00 GMT".
    static let rss: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter
    }()
}

/// Release notes, newest first.
public enum Releases {
    public static let all: [Release] = [
        Release(
            "2.4.1",
            date: "2026-09-22",
            summary: "A small follow-up to 2.4 with fixes reported in the first week.",
            size: 11_402_388,
            changes: [
                Change(.fixed, "Rules that watch iCloud Drive folders no longer run twice when a file finishes downloading."),
                Change(.fixed, "Shelves pinned to the right edge keep their position after changing display scaling."),
                Change(.improved, "Quick Look opens faster for large PDFs on Intel Macs."),
            ]
        ),
        Release(
            "2.4.0",
            date: "2026-09-15",
            title: "Rules for every Space",
            summary: "Rules were global until now. In 2.4 each Space can have its own set, so a client Space can file that client's downloads without touching anything else.",
            size: 11_388_214,
            changes: [
                Change(.new, "Per-Space Rules, with a global section for rules that should always run."),
                Change(.new, "Rule preview shows the files a rule would catch before you turn it on."),
                Change(.new, "Undo the last automatic move from the menu bar for up to ten minutes."),
                Change(.improved, "The Rules pane was redesigned with plain-language conditions."),
            ]
        ),
        Release(
            "2.3.2",
            date: "2026-08-28",
            summary: "Stability release.",
            changes: [
                Change(.fixed, "A rare crash when dragging a folder alias onto a collapsed shelf."),
                Change(.fixed, "Dock stack showed the previous Space's items after waking from sleep."),
            ]
        ),
        Release(
            "2.3.0",
            date: "2026-08-04",
            title: "Focus-aware Spaces",
            summary: "Spaces can now follow your Focus modes. Turn on Work and your Studio Space comes forward; switch to Personal and it steps aside.",
            changes: [
                Change(.new, "Link any Space to one or more Focus modes."),
                Change(.new, "Space colors tint the menu bar icon so you always know where you are."),
                Change(.improved, "Switching Spaces is smoother on 120 Hz displays."),
            ]
        ),
        Release(
            "2.2.0",
            date: "2026-06-30",
            title: "Search everything",
            changes: [
                Change(.new, "⌘K searches every shelf in every Space, including indexed file contents."),
                Change(.new, "Web links on shelves show page titles and favicons, fetched once and stored locally."),
                Change(.fixed, "Sorting by date added now survives a relaunch."),
            ]
        ),
        Release(
            "2.0.0",
            date: "2026-04-14",
            title: "Shelf 2",
            summary: "A rebuilt app with Spaces, a new settings window and support for multiple displays. Free for every 1.x license holder.",
            changes: [
                Change(.new, "Spaces: saved sets of shelves you can switch between instantly."),
                Change(.new, "Multi-display support that remembers which screen each shelf lives on."),
                Change(.new, "Import and export layouts as .shelfspace files."),
                Change(.improved, "Rewritten in Swift with native materials; uses noticeably less memory than 1.x."),
            ]
        ),
    ]

    public static var latest: Release { all[0] }
}
