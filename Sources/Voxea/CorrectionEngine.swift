import Foundation

struct CorrectionChange: Identifiable {
    let ruleID: UUID
    let location: Int
    let heard: String
    let replacement: String
    let suggestion: Bool
    var id: String { "\(ruleID.uuidString)-\(location)" }
}
struct CorrectionResult {
    let text: String
    let applied: [CorrectionChange]
    let suggestions: [CorrectionChange]
    var usage: [UUID: Int] {
        applied.reduce(into: [:]) { $0[$1.ruleID, default: 0] += 1 }
    }
}
struct CorrectionEngine {
    private struct Entry { let rule: CorrectionRule; let pattern: NSRegularExpression }
    private let entries: [Entry]
    init(rules: [CorrectionRule]) {
        entries = rules.filter(\.enabled).compactMap { rule in
            let parts = rule.heard.precomposedStringWithCanonicalMapping.split(whereSeparator: { $0.isWhitespace })
            guard !parts.isEmpty else { return nil }
            let escaped = parts.map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "[\\p{Zs}\\t]+")
            let pattern = "(?<![\\p{L}\\p{N}\\p{M}_])" + escaped + "(?![\\p{L}\\p{N}\\p{M}_])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            return Entry(rule: rule, pattern: regex)
        }
    }
    func apply(_ raw: String, bundleID: String?, includeSuggestions: Bool = false) -> CorrectionResult {
        guard !raw.isEmpty, !entries.isEmpty else { return CorrectionResult(text: raw, applied: [], suggestions: []) }
        // A scoped rule overrides the global rule for the same heard phrase,
        // including when the scoped rule requests a suggestion instead of automation.
        let eligible = entries.filter { $0.rule.scopeBundleID.isEmpty || $0.rule.scopeBundleID == bundleID }
        let selected = Dictionary(grouping: eligible, by: { CorrectionRule.key($0.rule.heard) }).values.compactMap { group in
            group.first { !$0.rule.scopeBundleID.isEmpty } ?? group.first
        }
        let original = raw.precomposedStringWithCanonicalMapping as NSString
        struct Match { let range: NSRange; let entry: Entry }
        let matches = selected.flatMap { entry in
            entry.pattern.matches(in: original as String, range: NSRange(location: 0, length: original.length))
                .map { Match(range: $0.range, entry: entry) }
        }.sorted {
            if $0.range.location != $1.range.location { return $0.range.location < $1.range.location }
            if $0.range.length != $1.range.length { return $0.range.length > $1.range.length }
            return $0.entry.rule.id.uuidString < $1.entry.rule.id.uuidString
        }
        var result = ""; var cursor = 0; var occupiedEnd = 0
        var applied: [CorrectionChange] = []; var suggestions: [CorrectionChange] = []
        for match in matches where match.range.location >= occupiedEnd {
            occupiedEnd = NSMaxRange(match.range)
            let heard = original.substring(with: match.range)
            let rule = match.entry.rule
            guard heard != rule.replacement else { continue }
            let change = CorrectionChange(ruleID: rule.id, location: match.range.location, heard: heard, replacement: rule.replacement, suggestion: rule.mode == .suggestion)
            if rule.mode == .automatic || includeSuggestions {
                result += original.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                result += rule.replacement; cursor = NSMaxRange(match.range); applied.append(change)
            } else { suggestions.append(change) }
        }
        result += original.substring(from: cursor)
        // No sequential string replacements: replacement output is never rescanned.
        return CorrectionResult(text: applied.isEmpty ? raw : result, applied: applied, suggestions: suggestions)
    }
}
