import Foundation

/// How long a passage takes to read, as a phrase rather than a number.
///
/// Measured over the shipped bundle before the rule was chosen: a Daily Minute
/// is 144-342 words and reads "about 1 min", agreeing with the name on the card
/// above it; 48% of the 365 lessons are under 200 words, so the floor below one
/// minute is the common case and not an edge; the longest Text section, 5,839
/// words, reads "about 29 min".
///
/// Pure by design — no SwiftUI, no `Bundle`, no `CorpusService` — so
/// `tools/verify_reading_time.sh` can compile it alone.
enum ReadingTime {
    /// A silent reading pace. Not the narration's pace: the recordings run
    /// faster than this, and this number answers "how long will this take me",
    /// not "how long is the audio".
    static let wordsPerMinute = 200

    /// Words in a body, counted the one way this app counts them.
    ///
    /// ⛔ Splits on newlines as well as spaces. Every bundled body is
    /// paragraphs joined by "\n\n", so a space-only split reads "end.\n\nBegin"
    /// as a single word and undercounts a long section by its paragraph count.
    /// This matches `CorpusTextSection.wordCount` and Python's `str.split()`,
    /// and the harness proves all three agree over the whole bundle.
    static func wordCount(of body: String) -> Int {
        body.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }

    /// The phrase for a word count, or nil when there is nothing to measure.
    ///
    /// ⛔ Nil rather than "about 0 min". A reading whose count is unknown — an
    /// archived row carries none — draws no measure at all, because a confident
    /// zero is worse than a blank.
    static func describe(wordCount: Int) -> String? {
        guard wordCount > 0 else { return nil }
        let minutes = Double(wordCount) / Double(wordsPerMinute)
        guard minutes >= 1 else { return "less than a minute" }
        return "about \(Int(minutes.rounded())) min"
    }
}
