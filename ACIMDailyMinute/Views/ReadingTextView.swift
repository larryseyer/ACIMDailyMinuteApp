import SwiftUI

/// Splits publisher text into display paragraphs.
///
/// The two feeds disagree about whitespace: Lesson text arrives hard-wrapped at
/// roughly 60 characters, Minute text arrives as a single flow. Both use a
/// blank line to mean "new paragraph", so a lone newline is a wrapping artifact
/// to be collapsed while a blank line is structure to be preserved.
enum ReadingText {
    private static let paragraphSeparator = "\u{1}"

    static func paragraphs(from raw: String) -> [String] {
        raw
            .replacingOccurrences(
                of: "\n[ \t]*\n[ \t\n]*",
                with: paragraphSeparator,
                options: .regularExpression
            )
            .components(separatedBy: paragraphSeparator)
            .map { block in
                block
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    /// The exact string a reader sees, as one value.
    ///
    /// Highlight offsets are measured against this and nothing else. If the
    /// renderer and the anchor arithmetic ever disagree about what the reader is
    /// looking at, every stored offset is wrong by a variable amount and nothing
    /// about the failure looks like a bug until someone reopens an old
    /// highlight. One function, both callers.
    static func displayString(from raw: String) -> String {
        paragraphs(from: raw).joined(separator: "\n\n")
    }
}

/// Renders a reading as spaced paragraphs rather than one undifferentiated
/// block. Text with no paragraph breaks renders exactly as it did before, so
/// this degrades to the previous behavior when the feed carries no structure.
struct ReadingTextView: View {
    let raw: String
    var spacing: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(ReadingText.paragraphs(from: raw).enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
