import SwiftUI

/// One reading on the wrist: the words, then where they sit in the book.
///
/// ⛔ It takes an address rather than a lesson number. The row used to print
/// `Lesson N` above the Daily Minute's text, and a Daily Minute is a **random**
/// segment the publisher chose — never lesson N. That caption was not merely
/// dead, it was a sentence that would have been false the moment it populated.
struct WatchStoryRow: View {
    let address: String?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.tight) {
            // The watch has no reading surface, so it repairs the feed's
            // spacing where it draws it. No line cap: the list scrolls.
            Text(PunctuationSpacing.repaired(text))
                .font(.acimReading)
            CitationLabel(raw: address)
        }
    }
}
