import Foundation

struct FormattingOptions: Codable, Equatable {
    var removeFinalPeriod = true
    var capitalize = true
    var voiceCommands = true
    var removeHesitations = true
}

struct FormattingPreferences: Codable {
    var global = FormattingOptions()
    var applications: [String: FormattingOptions] = [:]
    func options(for bundleID: String?) -> FormattingOptions {
        bundleID.flatMap { applications[$0] } ?? global
    }
}

enum TextFormatting {
    // Commands are literal phrases, never instructions sent to another service.
    static let commands: [(phrase: String, effect: String)] = [
        ("à la ligne", "Retour à la ligne"),
        ("nouveau paragraphe", "Ligne vide entre deux paragraphes"),
        ("faire une liste", "Commencer une liste à puces"),
        ("élément suivant", "Ajouter une nouvelle puce dans la liste"),
        ("fin de liste", "Terminer la liste et revenir au texte")
    ]
    static func apply(_ input: String, options: FormattingOptions) -> String {
        var text = input
        if options.removeHesitations || options.voiceCommands { text = text.trimmingCharacters(in: .whitespaces) }
        if options.removeHesitations {
            // Only standalone fillers; do not remove meaningful words such as « bon » or « alors ».
            text = replacing("(?i)(?<![\\p{L}\\p{N}_])(?:euh+|heu+|uh+|um+)(?![\\p{L}\\p{N}_])[ \\t]*(?:[,;.!?:]+[ \\t]*)?", in: text, with: "")
        }
        if options.voiceCommands { text = expandCommands(text) }
        if options.removeHesitations || options.voiceCommands {
            text = replacing("[ \\t]{2,}", in: text, with: " ")
            text = replacing("[ \\t]+([,.])", in: text, with: "$1")
            text = replacing("[ \\t]*\\n[ \\t]*", in: text, with: "\n")
            text = text.trimmingCharacters(in: .whitespaces)
        }
        if options.capitalize {
            var sentenceStart = true
            var result = ""
            for character in text {
                if character.isLetter && sentenceStart {
                    result += String(character).uppercased(); sentenceStart = false
                } else {
                    result.append(character)
                    if character.isLetter || character.isNumber { sentenceStart = false }
                }
                if ".!?\n".contains(character) { sentenceStart = true }
            }
            text = result
        }
        if options.removeFinalPeriod {
            // Remove a single sentence period, preserving ellipses, abbreviations and trailing whitespace.
            if let end = text.lastIndex(where: { !$0.isWhitespace }), text[end] == "." {
                let prefix = String(text[..<end])
                if !prefix.hasSuffix("."), !prefix.hasSuffix("…"),
                   !matches("(?i)(?:\\b(?:etc|dr|mr|mrs|ms|mme|mlle|m)|(?:\\b\\p{L}\\.)+\\p{L}|\\b\\p{Lu})$", prefix) {
                    text.remove(at: end)
                }
            }
        }
        return text
    }
    private static func expandCommands(_ input: String) -> String {
        let phrases = commands.map { NSRegularExpression.escapedPattern(for: $0.phrase).replacingOccurrences(of: " ", with: "[\\p{Zs}\\t]+") }.joined(separator: "|")
        guard let regex = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_])(?:\(phrases))(?![\\p{L}\\p{N}_])", options: [.caseInsensitive]) else { return input }
        let source = input as NSString
        var result = "", cursor = 0, inList = false
        for match in regex.matches(in: input, range: NSRange(location: 0, length: source.length)) {
            let phrase = source.substring(with: match.range)
                .lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            // « élément suivant » only acts inside a list.
            if phrase == "élément suivant" && !inList { continue }
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result = result.replacingOccurrences(of: "[ \\t]+$", with: "", options: .regularExpression)
            switch phrase {
            case "à la ligne": result += inList ? "\n• " : "\n"
            case "nouveau paragraphe": result += "\n\n"; inList = false
            case "faire une liste":
                if !result.isEmpty && !result.hasSuffix("\n") { result += "\n" }
                result += "• "; inList = true
            case "élément suivant": result += "\n• "
            case "fin de liste": result += "\n"; inList = false
            default: break
            }
            cursor = NSMaxRange(match.range)
            // ASR often adds punctuation immediately after a spoken command.
            while cursor < source.length, " \t,.:;!?".contains(source.substring(with: NSRange(location: cursor, length: 1))) { cursor += 1 }
        }
        result += source.substring(from: cursor)
        return result
    }
    private static func replacing(_ pattern: String, in text: String, with replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
