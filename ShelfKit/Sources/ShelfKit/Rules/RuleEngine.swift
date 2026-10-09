import Foundation

/// Decides which rule, if any, applies to a file. Pure and synchronous so it can be previewed and tested.
public struct RuleEngine: Sendable {
    public var now: @Sendable () -> Date
    public var calendar: Calendar

    public init(now: @escaping @Sendable () -> Date = { Date() }, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar
    }

    public func matches(_ rule: Rule, _ candidate: FileCandidate) -> Bool {
        guard rule.isEnabled, rule.condition.isValid, rule.source.matches(candidate.source) else { return false }

        switch rule.condition {
        case let .extensionIs(ext):
            return candidate.url.pathExtension.lowercased() == Rule.Condition.normalizedExtension(ext)
        case let .nameContains(text):
            let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return candidate.fileName.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
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
    /// Rules that belong to another Space never run.
    public func firstMatch(in rules: [Rule], for candidate: FileCandidate, activeSpaceID: Space.ID?) -> Rule? {
        orderedRules(rules, activeSpaceID: activeSpaceID).first { matches($0, candidate) }
    }

    /// The rules that are in play for a Space, in the order they are tried.
    public func orderedRules(_ rules: [Rule], activeSpaceID: Space.ID?) -> [Rule] {
        let spaceRules = rules.filter { $0.spaceID != nil && $0.spaceID == activeSpaceID }
        let globalRules = rules.filter(\.isGlobal)
        return spaceRules + globalRules
    }

    /// The files a rule would catch, shown before the user turns it on.
    public func preview(_ rule: Rule, in candidates: [FileCandidate]) -> [FileCandidate] {
        var enabled = rule
        enabled.isEnabled = true
        return candidates.filter { matches(enabled, $0) }
    }

    /// The folders that need watching for the enabled rules of a Space, without duplicates.
    public func watchedSources(for rules: [Rule], activeSpaceID: Space.ID?) -> [Rule.Source] {
        var seen: [Rule.Source] = []
        for rule in orderedRules(rules, activeSpaceID: activeSpaceID) where rule.isEnabled && rule.source != .anyShelf {
            if !seen.contains(where: { $0.matches(rule.source) }) {
                seen.append(rule.source)
            }
        }
        return seen
    }
}
