import Foundation

/// Finds a highlight's words again after the text under it has changed.
///
/// Offsets are measured against `ReadingText.displayString(from:)` and nothing
/// else. Callers must pass that exact string.
enum AnchorResolver {
    enum Resolution: Equatable {
        /// The stored range still holds the quote. The ordinary case.
        case exact(Range<Int>)
        /// The quote moved; the range has been corrected and should be saved.
        case moved(Range<Int>)
        /// The quote is gone. Keep the highlight and flag it.
        case orphaned
    }

    static func resolve(
        startOffset: Int,
        length: Int,
        quote storedQuote: String,
        in display: String
    ) -> Resolution {
        // A quote captured before the spacing repair reads `planned.We must`
        // while the text now reads `planned. We must`, and would never be found
        // again. Repairing the quote by the same rule the display went through
        // makes the two comparable; the rule is idempotent, so a quote captured
        // afterwards is untouched.
        let quote = PunctuationSpacing.repaired(storedQuote)
        guard !quote.isEmpty else { return .orphaned }
        let chars = Array(display)

        if startOffset >= 0, length > 0, startOffset + length <= chars.count,
           String(chars[startOffset..<(startOffset + length)]) == quote {
            return .exact(startOffset..<(startOffset + length))
        }

        let occurrences = allOccurrences(of: Array(quote), in: chars)
        guard let best = occurrences.min(by: {
            abs($0 - startOffset) < abs($1 - startOffset)
        }) else { return .orphaned }

        return .moved(best..<(best + quote.count))
    }

    /// Every start index, so an ambiguous quote can be resolved by proximity
    /// rather than by taking the first hit — the Course repeats itself
    /// constantly, and first-hit would silently move a reader's mark to a
    /// different chapter.
    private static func allOccurrences(of needle: [Character], in haystack: [Character]) -> [Int] {
        guard !needle.isEmpty, needle.count <= haystack.count else { return [] }
        var found: [Int] = []
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<(start + needle.count)]) == needle { found.append(start) }
        }
        return found
    }
}
