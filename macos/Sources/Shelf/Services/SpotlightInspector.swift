import CoreServices
import Foundation
import ShelfKit

/// Reads Spotlight's screen-capture flag and last-used date, which are more reliable than file
/// names and access dates. Falls back to ShelfKit's file-system inspector when a file isn't indexed.
struct SpotlightInspector: CandidateInspecting {
    private let fallback = FileSystemInspector()

    func inspect(_ url: URL, source: Rule.Source) -> FileCandidate {
        var candidate = fallback.inspect(url, source: source)
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else { return candidate }

        if let isScreenCapture = MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) as? Bool {
            candidate.isScreenshot = isScreenCapture
        }
        if let lastUsed = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date {
            candidate.lastUsed = lastUsed
        }
        return candidate
    }
}
