import SwiftUI

/// One reading on the wrist: where it sits in the book, then the words.
///
/// ⛔ It takes an address rather than a lesson number. The row used to print
/// `Lesson N` above the Daily Minute's text, and a Daily Minute is a **random**
/// segment the publisher chose — never lesson N. That caption was not merely
/// dead, it was a sentence that would have been false the moment it populated.
struct WatchStoryRow: View {
    let address: String?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let address {
                Text(address)
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }
            // The watch has no reading surface, so it repairs the feed's
            // spacing where it draws it.
            Text(PunctuationSpacing.repaired(text))
                .font(.footnote)
                .lineLimit(6)
        }
    }
}
