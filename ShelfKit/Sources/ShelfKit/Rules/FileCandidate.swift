import Foundation

/// A file the rule engine is asked about: a new arrival in a watched folder, or an item already on a shelf.
public struct FileCandidate: Hashable, Sendable {
    public var url: URL
    public var source: Rule.Source
    public var isScreenshot: Bool
    public var lastUsed: Date?

    public init(url: URL, source: Rule.Source, isScreenshot: Bool = false, lastUsed: Date? = nil) {
        self.url = url
        self.source = source
        self.isScreenshot = isScreenshot
        self.lastUsed = lastUsed
    }

    public var fileName: String { url.lastPathComponent }

    /// A shelf item seen as a candidate for `.anyShelf` rules (archiving).
    public init(shelfItem item: ShelfItem) {
        self.init(url: item.url, source: .anyShelf, isScreenshot: false, lastUsed: item.lastUsed)
    }
}

/// Reads the facts Rules need about a file on disk. The macOS app supplies a Spotlight-backed
/// inspector; `FileSystemInspector` is the portable fallback.
public protocol CandidateInspecting: Sendable {
    func inspect(_ url: URL, source: Rule.Source) -> FileCandidate
}

/// Uses file-system metadata only: the access date for "untouched", and the names macOS gives
/// screenshots and screen recordings for "is a screenshot".
public struct FileSystemInspector: CandidateInspecting {
    public init() {}

    public func inspect(_ url: URL, source: Rule.Source) -> FileCandidate {
        let values = try? url.resourceValues(forKeys: [.contentAccessDateKey, .contentModificationDateKey])
        return FileCandidate(
            url: url,
            source: source,
            isScreenshot: ScreenshotName.matches(url.lastPathComponent),
            lastUsed: values?.contentAccessDate ?? values?.contentModificationDate
        )
    }
}

/// Recognises the default names macOS gives screenshots ("Screenshot 2026-09-24 at 09.41.12.png",
/// "Screen Shot …" on older systems, "Screen Recording …").
public enum ScreenshotName {
    private static let prefixes = ["screenshot", "screen shot", "screen recording", "cleanshot"]
    private static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "mov", "mp4"]

    public static func matches(_ fileName: String) -> Bool {
        let lowered = fileName.lowercased()
        let ext = (lowered as NSString).pathExtension
        guard extensions.contains(ext) else { return false }
        return prefixes.contains { lowered.hasPrefix($0) }
    }
}
