import SwiftUI
import SwiftData

/// One marked passage in the Saved tab.
///
/// The reader's own date is shown; when the reading was published is not, and
/// never is. An orphaned highlight is the same row at 50% opacity — the words
/// are still the reader's; only their place is lost.
struct HighlightRow: View {
    let highlight: Highlight

    private let key: ReadingKey?

    init(highlight: Highlight) {
        self.highlight = highlight
        self.key = ReadingKey(rawValue: highlight.readingKey)
    }

    /// The mark itself, handed to the screen so it opens on the reader's own
    /// sentence rather than at the top. `AnchorResolver` repairs it on arrival,
    /// which is what makes it survive a published reading drawing the feed's
    /// text instead of the bundle's.
    private var spotlight: ReadingSpotlight? {
        guard highlight.length > 0, !highlight.quote.isEmpty else { return nil }
        return ReadingSpotlight(
            startOffset: highlight.startOffset,
            length: highlight.length,
            quote: highlight.quote
        )
    }

    var body: some View {
        if let destination = key?.savedDestination(spotlight: spotlight) {
            NavigationLink(value: destination) { rowContent }
                .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        SavedMarkChrome(
            quote: highlight.quote,
            paintsHighlight: true,
            citationRaw: SavedCitation.raw(for: highlight),
            dateText: SavedMarkCopy.dateText(kind: "Highlighted", at: highlight.createdAt),
            isDimmed: highlight.isOrphaned
        )
    }
}
