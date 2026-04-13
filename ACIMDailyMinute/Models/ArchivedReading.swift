import Foundation
import SwiftData

/// A single archived ACIM passage from either the Daily Minute or Daily Lesson stream.
///
/// Populated by `ArchiveService` from the rolling `archive[]` array inside each
/// channel's JSON endpoint, deduplicated by `lineHash`. Drives the Archive tab's
/// calendar view and the full-text search UI.
///
/// Search uses `#Predicate` filtering against `searchableText`, which concatenates
/// the body plus source reference plus lesson title (where applicable), so callers
/// don't need to traverse into child arrays that SwiftData predicates handle poorly.
@Model
final class ArchivedReading {
    /// Stable content hash used as the unique identity.
    ///
    /// Derived from `channel + dateString + text` via SHA-256 (truncated). Because
    /// the hash is deterministic, re-parsing the same archive produces the same IDs,
    /// so repeat ingestion is idempotent.
    @Attribute(.unique) var lineHash: String = ""

    /// `"daily-minute"` or `"daily-lesson"` — the source stream.
    var channel: String = ""

    /// `"YYYY-MM-DD"` — the reading's publication date.
    ///
    /// Stored as a String (rather than a `Date`) because lexicographic sort on
    /// `YYYY-MM-DD` naturally matches chronological order and `#Predicate`
    /// comparisons on strings are cheap.
    var dateString: String = ""

    /// Parsed publication timestamp. `nil` when the archive entry's date
    /// couldn't be parsed as ISO-8601.
    var timestamp: Date?

    /// The passage body itself.
    var text: String = ""

    /// Human-readable source reference (e.g. "Text Part A", "Manual").
    /// Empty string for Daily Lesson archive entries.
    var sourceReference: String = ""

    /// Workbook lesson number (1–365) when `channel == "daily-lesson"`.
    /// `nil` for Daily Minute archive entries.
    var lessonNumber: Int?

    /// Relative audio URL from the archive entry, resolved against the channel's
    /// base URL by `AudioManager`. `nil` on entries that predate the audio column.
    var audioURL: String?

    /// Concatenation of `text`, `sourceReference`, and `lessonTitle` (when present),
    /// joined by spaces. Exists as a dedicated field because SwiftData `#Predicate`
    /// closures don't traverse into child arrays cleanly — one flat string keeps
    /// search queries trivially expressible.
    var searchableText: String = ""

    init() {}
}
