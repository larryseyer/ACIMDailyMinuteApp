import Foundation
import SwiftData

/// A passage the reader marked.
///
/// Three things together, because no one of them survives alone: the reading it
/// belongs to, where in that reading it sat, and the words themselves. The
/// publisher corrects readings, and when that happens the offset drifts — so the
/// quote is what finds it again. See `AnchorResolver`.
///
/// `id` is a UUID, not a hash of the quote. The same phrase recurs all over the
/// Course, and hashing content is the bug this project keeps rediscovering.
/// It carries no `@Attribute(.unique)`: SwiftData refuses that in a
/// CloudKit-backed store, and a UUID is unique by construction anyway, so the
/// index was buying nothing.
///
/// `readingKey` holds a `ReadingKey.rawValue`. `startOffset` and `length` are
/// `Character` counts into `ReadingText.displayString(from:)`, not UTF-16 units.
@Model
final class Highlight {
    var id: UUID = UUID()
    var readingKey: String = ""
    var startOffset: Int = 0
    var length: Int = 0
    var quote: String = ""
    var createdAt: Date = Date()
    /// The quote could not be found on last open. Kept, never deleted: the words
    /// are still the ones the reader chose.
    var isOrphaned: Bool = false

    init() {}
}
