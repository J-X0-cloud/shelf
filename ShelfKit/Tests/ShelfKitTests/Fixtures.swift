import Foundation
@testable import ShelfKit

/// Records what the coordinator asked the system to do.
final class RecordingWorkspace: WorkspaceServicing {
    private(set) var syncedStacks: [[ShelfItem]] = []
    private(set) var openedItems: [ShelfItem] = []
    var failSync = false

    func syncDockStack(with items: [ShelfItem]) throws {
        if failSync { throw CocoaError(.fileWriteNoPermission) }
        syncedStacks.append(items)
    }

    func open(_ item: ShelfItem) {
        openedItems.append(item)
    }
}

/// Hands back canned facts instead of reading Spotlight or the disk.
struct StubInspector: CandidateInspecting {
    var screenshots: Set<String> = []
    var lastUsed: [String: Date] = [:]

    func inspect(_ url: URL, source: Rule.Source) -> FileCandidate {
        FileCandidate(
            url: url,
            source: source,
            isScreenshot: screenshots.contains(url.lastPathComponent),
            lastUsed: lastUsed[url.lastPathComponent]
        )
    }
}

/// A mutable clock the tests can move forward.
final class TestClock: @unchecked Sendable {
    var now: Date

    init(_ iso: String = "2026-09-24T09:41:00Z") {
        now = ISO8601DateFormatter().date(from: iso)!
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

enum Fixtures {
    static let inbox = Shelf(name: "Inbox", colorHex: "#E4572E")
    static let paperwork = Shelf(name: "Paperwork", colorHex: "#E9B44C")
    static let brand = Shelf(name: "Brand", colorHex: "#5E9C7E")
    static let archive = Shelf(name: "Archive", colorHex: "#7FA7D9", autoHide: true)

    static let studio = Space(name: "Studio", colorHex: "#E4572E", shelves: [inbox, archive], focusModes: ["Work"])
    static let harbor = Space(name: "Harbor Coffee rebrand", colorHex: "#5E9C7E", shelves: [brand])
    static let admin = Space(name: "Admin & invoices", colorHex: "#E9B44C", shelves: [paperwork])

    static let folders = KnownFolders(
        downloads: URL(fileURLWithPath: "/Users/test/Downloads", isDirectory: true),
        desktop: URL(fileURLWithPath: "/Users/test/Desktop", isDirectory: true)
    )

    static func layout(rules: [Rule] = []) -> ShelfLayout {
        ShelfLayout(spaces: [studio, harbor, admin], rules: rules, activeSpaceID: studio.id)
    }

    static func file(_ name: String, in folder: String = "/Users/test/Downloads") -> URL {
        URL(fileURLWithPath: folder).appendingPathComponent(name)
    }

    static func item(_ name: String, in folder: String = "/Users/test/Downloads", addedAt: Date = Date(timeIntervalSince1970: 1_790_000_000)) -> ShelfItem {
        ShelfItem(url: file(name, in: folder), addedAt: addedAt)
    }

    /// A fresh, empty directory under the system temporary folder.
    static func temporaryDirectory(_ name: String = #function) throws -> URL {
        let safe = name.filter { $0.isLetter || $0.isNumber }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShelfKitTests-\(safe)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
