import Foundation

/// Turns raw Whisper output into the text we paste, or nil when there is nothing worth pasting.
public enum TranscriptCleaner {
    /// Phrases Whisper tends to invent for silence or noise. Compared lowercased, without punctuation.
    static let hallucinations: Set<String> = [
        "thank you", "thanks for watching", "thank you for watching", "you", "bye",
    ]

    public static func clean(_ raw: String) -> String? {
        var text = raw
        // Annotations like [Music], [BLANK_AUDIO], (silence).
        text = replace(#"\[[^\]]*\]|\([^)]*\)"#, in: text, with: " ")

        let fillerPattern = #"\b(?:um+|uh+|erm+|hmm+|mm+)\b[,.]?"#
        let startsWithFiller = text.range(
            of: #"^\s*"# + fillerPattern, options: [.regularExpression, .caseInsensitive]) != nil
        text = replace(fillerPattern, in: text, with: " ")

        text = replace(#"\s+"#, in: text, with: " ")
        text = replace(#"\s+([,.!?;:])"#, in: text, with: "$1")
        text = text.trimmingCharacters(in: .whitespaces)

        let bare = text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        if bare.isEmpty || hallucinations.contains(bare) { return nil }

        if startsWithFiller, let first = text.first {
            text = first.uppercased() + text.dropFirst()
        }
        return text
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        text.replacingOccurrences(
            of: pattern, with: template, options: [.regularExpression, .caseInsensitive])
    }
}
