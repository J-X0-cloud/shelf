import Foundation

/// Works out which files are new each time a watched folder changes. The macOS app feeds it from
/// a `DispatchSource` file-system event; it is plain state so the tricky cases can be tested:
/// browsers and iCloud write partial files first, and iCloud can report the same file twice
/// while a download finishes.
public struct FolderChangeDetector: Sendable {
    /// Extensions used for files that are still being written.
    public static let partialExtensions: Set<String> = ["download", "crdownload", "part", "partial", "icloud", "tmp"]

    /// A file reported within this window is not reported again (the iCloud double-run fix in 2.4.1).
    public var duplicateWindow: TimeInterval

    private var known: Set<String>
    private var recentlyReported: [String: Date] = [:]

    /// Starts from the folder's current contents, so files that were already there never trigger rules.
    public init(existing: [URL], duplicateWindow: TimeInterval = 30) {
        self.duplicateWindow = duplicateWindow
        known = Set(existing.map(FolderChangeDetector.key))
    }

    /// Takes the folder's contents after a change and returns the files that should be offered to Rules.
    public mutating func update(with contents: [URL], at date: Date) -> [URL] {
        let current = Dictionary(contents.map { (FolderChangeDetector.key($0), $0) }, uniquingKeysWith: { first, _ in first })
        let added = current
            .filter { !known.contains($0.key) }
            .map(\.value)
            .filter { !FolderChangeDetector.isTransient($0) }

        known = Set(current.keys)
        recentlyReported = recentlyReported.filter { date.timeIntervalSince($0.value) < duplicateWindow }

        var reported: [URL] = []
        for url in added.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let key = FolderChangeDetector.key(url)
            guard recentlyReported[key] == nil else { continue }
            recentlyReported[key] = date
            reported.append(url)
        }
        return reported
    }

    /// Hidden files, partial downloads and iCloud placeholders (".Name.pdf.icloud").
    public static func isTransient(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") || name.hasPrefix("~$") { return true }
        return partialExtensions.contains(url.pathExtension.lowercased())
    }

    private static func key(_ url: URL) -> String {
        url.standardizedFileURL.path
    }
}
