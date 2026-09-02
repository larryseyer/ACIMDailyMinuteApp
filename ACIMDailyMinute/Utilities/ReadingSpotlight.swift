import Foundation

/// Where a reading should open: the words a search matched.
///
/// Carries the quote as well as the offsets because the screen may draw a
/// different string from the one the index was built over — a lesson the feed
/// has published draws the feed's text, the index was built over the bundle —
/// so the screen re-anchors it with `AnchorResolver`, exactly as a highlight
/// is. A pointer, not a mark: never stored, never exported, gone with the
/// screen.
struct ReadingSpotlight: Hashable, Sendable {
    let startOffset: Int
    let length: Int
    let quote: String
}
