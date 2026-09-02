import Foundation

/// The book's index: finds every place a run of words occurs in the readable
/// corpus, at the `Character` offset a highlight would use for the same words.
///
/// ⛔ Foundation only. No SwiftUI, SwiftData, `Bundle`, `CorpusService`,
/// `ReadingKey` or `Citation`. `tools/verify_corpus_search.sh` compiles this
/// file alone against every record in the shipped bundle, and that check is
/// what keeps a match's offset pointing at the words it names.
enum SearchFold {
    /// One `Character` in, one out. Lowercase, and the typographic forms the
    /// corpus uses mapped onto the keys a reader has: `‘ ’` → `'`, `“ ”` → `"`,
    /// `– —` → `-`. Applied to the corpus once and to every query, so `God's`
    /// finds `God’s`. Nothing else: the corpus has no accented characters.
    ///
    /// Length-preserving is load-bearing — an offset into the folded string is
    /// the same offset into the display string. The harness proves it over
    /// every shipped record.
    static func fold(_ s: String) -> String {
        var out = String()
        out.reserveCapacity(s.utf8.count)
        for c in s {
            switch c {
            case "‘", "’": out.append("'")
            case "“", "”": out.append("\"")
            case "–", "—": out.append("-")
            default:
                if c.isUppercase {
                    let lowered = c.lowercased()
                    // A Character whose lowercase is more than one Character
                    // (a handful of Unicode edge cases) is left as it is, so the
                    // count cannot change.
                    out.append(lowered.count == 1 ? Character(lowered) : c)
                } else {
                    out.append(c)
                }
            }
        }
        return out
    }

    /// The query as the index sees it: trimmed, inner whitespace collapsed to
    /// one space, folded. Nil when fewer than two characters remain — one
    /// letter is not a search, it is every page.
    static func normalizedQuery(_ raw: String) -> String? {
        let collapsed = raw
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
        guard collapsed.count >= 2 else { return nil }
        return fold(collapsed)
    }
}

/// One searchable reading. `id` is opaque here; the service that built the
/// record knows what it names.
struct SearchRecord: Sendable {
    let id: Int
    let title: String
    /// `ReadingText.displayString(from:)` of the reading — the string the
    /// reader sees, so an offset here is an offset a highlight would store.
    let display: String
}

/// Where a query occurs: which record, and the `Character` range within it.
struct SearchHit: Hashable, Sendable {
    let record: Int
    let range: Range<Int>
}

struct SearchResults: Sendable {
    let hits: [SearchHit]
    /// The scan stopped at the cap. The reader is told; the list is not
    /// presented as complete.
    let truncated: Bool

    static let none = SearchResults(hits: [], truncated: false)
}

/// The words around a hit, cut on word boundaries. `before` starts with `…`
/// when it was cut, `after` ends with one; neither carries an ellipsis at the
/// record's edge. Newlines are left in place; a row flattens them.
struct SearchSnippet: Hashable, Sendable {
    let before: String
    let match: String
    let after: String
}

final class SearchIndex: Sendable {
    static let hitCap = 1000

    let records: [SearchRecord]
    private let folded: [String]

    init(records: [SearchRecord]) {
        self.records = records
        self.folded = records.map { SearchFold.fold($0.display) }
    }

    /// Every non-overlapping occurrence of the query, in record order then
    /// offset order, stopping at `cap`. `shouldStop` is consulted once per
    /// record so a superseded query can abandon its scan.
    func search(
        _ rawQuery: String,
        cap: Int = SearchIndex.hitCap,
        shouldStop: () -> Bool = { false }
    ) -> SearchResults {
        guard let query = SearchFold.normalizedQuery(rawQuery) else { return .none }
        var hits: [SearchHit] = []
        hits.reserveCapacity(min(cap, 256))

        for (recordIndex, text) in folded.enumerated() {
            if shouldStop() { return SearchResults(hits: hits, truncated: true) }
            var cursor = text.startIndex
            var offset = 0
            while let found = text.range(of: query, options: .literal, range: cursor..<text.endIndex) {
                offset += text.distance(from: cursor, to: found.lowerBound)
                let length = text.distance(from: found.lowerBound, to: found.upperBound)
                if hits.count == cap {
                    return SearchResults(hits: hits, truncated: true)
                }
                hits.append(SearchHit(record: recordIndex, range: offset..<(offset + length)))
                offset += length
                cursor = found.upperBound
            }
        }
        return SearchResults(hits: hits, truncated: false)
    }

    /// Up to `context` characters either side of the hit, widened outward to
    /// the nearest word boundary so no word is cut, with `…` on a side that
    /// was cut and nothing on a side that reached the record's edge.
    func snippet(for hit: SearchHit, context: Int = 60) -> SearchSnippet {
        let display = records[hit.record].display
        let chars = Array(display)
        let lower = max(0, min(hit.range.lowerBound, chars.count))
        let upper = max(lower, min(hit.range.upperBound, chars.count))

        var start = max(0, lower - context)
        // Walk back to the start of the word that `start` landed in.
        while start > 0, !chars[start - 1].isWhitespace { start -= 1 }
        // Skip whitespace so the snippet begins on a word.
        while start < lower, chars[start].isWhitespace { start += 1 }

        var end = min(chars.count, upper + context)
        while end < chars.count, !chars[end].isWhitespace { end += 1 }
        while end > upper, chars[end - 1].isWhitespace { end -= 1 }

        let before = String(chars[start..<lower])
        let match = String(chars[lower..<upper])
        let after = String(chars[upper..<end])
        return SearchSnippet(
            before: start > 0 ? "…" + before : before,
            match: match,
            after: end < chars.count ? after + "…" : after
        )
    }
}
