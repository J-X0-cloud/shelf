import CoreServices
import Foundation

/// A file the rule engine is asked about: a new arrival in a watched folder, or an item already on a shelf.
struct FileCandidate: Hashable {
    var url: URL
    var source: Rule.Source
    var isScreenshot: Bool
    var lastUsed: Date?

    var fileName: String { url.lastPathComponent }

    /// Builds a candidate from disk, reading Spotlight's screen-capture flag and last-used date.
    static func inspect(_ url: URL, source: Rule.Source) -> FileCandidate {
        var isScreenshot = false
        var lastUsed: Date?
        if let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) {
            isScreenshot = (MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) as? Bool) ?? false
            lastUsed = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
        }
        if lastUsed == nil {
            lastUsed = try? url.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate
        }
        return FileCandidate(url: url, source: source, isScreenshot: isScreenshot, lastUsed: lastUsed)
    }
}

/// Decides which rule, if any, applies to a file. Pure and synchronous so it can be previewed and tested.
struct RuleEngine {
    var now: () -> Date = Date.init
    var calendar: Calendar = .current

    func matches(_ rule: Rule, _ candidate: FileCandidate) -> Bool {
        guard rule.isEnabled, sourceMatches(rule.source, candidate.source) else { return false }

        switch rule.condition {
        case let .extensionIs(ext):
            let wanted = ext.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
            return candidate.url.pathExtension.lowercased() == wanted
        case let .nameContains(text):
            return candidate.fileName.localizedCaseInsensitiveContains(text)
        case .isScreenshot:
            return candidate.isScreenshot
        case let .untouched(days):
            guard let lastUsed = candidate.lastUsed,
                  let cutoff = calendar.date(byAdding: .day, value: -days, to: now())
            else { return false }
            return lastUsed < cutoff
        }
    }

    /// Rules for the active Space win over global rules; within each group, list order decides.
    func firstMatch(in rules: [Rule], for candidate: FileCandidate, activeSpaceID: Space.ID?) -> Rule? {
        let spaceRules = rules.filter { $0.spaceID != nil && $0.spaceID == activeSpaceID }
        let globalRules = rules.filter { $0.spaceID == nil }
        return (spaceRules + globalRules).first { matches($0, candidate) }
    }

    /// The files a rule would catch, shown before the user turns it on.
    func preview(_ rule: Rule, in candidates: [FileCandidate]) -> [FileCandidate] {
        var enabled = rule
        enabled.isEnabled = true
        return candidates.filter { matches(enabled, $0) }
    }

    private func sourceMatches(_ ruleSource: Rule.Source, _ candidateSource: Rule.Source) -> Bool {
        switch (ruleSource, candidateSource) {
        case let (.folder(a), .folder(b)):
            return a.standardizedFileURL == b.standardizedFileURL
        default:
            return ruleSource == candidateSource
        }
    }
}
