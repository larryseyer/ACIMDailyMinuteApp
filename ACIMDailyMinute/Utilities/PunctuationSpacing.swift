import Foundation

/// Puts back the space the page had and the PDF text layer lost.
///
/// `their Source,Which is`, `William Thetford.The edit`, `original sin.”To
/// study`. The defect is in the source PDFs' own text layer, so it reaches the
/// app through both tiers: the bundled corpus, where `tools/export_corpus.py`
/// repairs it once at export, and the feed, where nothing can repair it but the
/// app. This is the app's half, and it is deliberately the same rule.
///
/// The rule inserts one space and never removes or changes a character, so a
/// word the publisher narrated stays the word the publisher narrated. It is
/// idempotent, which is what lets it run at export *and* at render without the
/// two disagreeing about what the reader is looking at.
enum PunctuationSpacing {
    /// Terminal or internal punctuation, or a closing double quote, run
    /// straight into the next sentence or quotation.
    private static let runTogether = "([.,;:!?”])([A-Z“‘])"

    /// A closing single quote run into the next word. The negative lookahead is
    /// the whole difficulty: `GOD’S PLAN` is a possessive and must be left
    /// alone, while `the only ‘sacrifice’You ask` is the defect. They are
    /// separable because no `’S` in the corpus is followed by a lowercase
    /// letter.
    private static let closingSingleQuote = "(’)(?!S(?![A-Za-z]))([A-Z])"

    /// The text with its missing spaces restored.
    static func repaired(_ text: String) -> String {
        text
            .replacingOccurrences(of: runTogether, with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: closingSingleQuote, with: "$1 $2", options: .regularExpression)
    }
}
