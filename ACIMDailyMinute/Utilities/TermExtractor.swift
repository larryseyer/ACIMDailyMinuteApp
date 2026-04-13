import Foundation

enum TermExtractor {
    private static let stopWords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "is", "was", "are", "were", "be", "been",
        "being", "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "may", "might", "shall", "can", "need", "must",
        "that", "this", "these", "those", "it", "its", "they", "their",
        "them", "we", "our", "he", "she", "his", "her", "not", "no",
        "more", "most", "some", "any", "all", "each", "every", "both",
        "than", "then", "also", "just", "about", "over", "after", "before",
        "into", "through", "during", "between", "under", "against", "since",
        "without", "within", "along", "following", "across", "behind",
        "said", "says", "new", "will", "been", "who", "which", "when",
        "what", "where", "how", "many", "much", "very", "only", "other",
        "such", "like", "well", "back", "even", "still", "also", "here",
        "there", "while", "according"
    ]

    static func candidates(from text: String, limit: Int = 8) -> [String] {
        let words = text.components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        var properNouns: [String] = []
        var regularWords: [String] = []

        for word in words {
            let lower = word.lowercased()
            guard word.count >= 4,
                  !stopWords.contains(lower),
                  !seen.contains(lower)
            else { continue }

            seen.insert(lower)

            let firstChar = word.first!
            if firstChar.isUppercase {
                properNouns.append(word)
            } else {
                regularWords.append(word)
            }
        }

        let ranked = properNouns + regularWords
        return Array(ranked.prefix(limit))
    }
}
