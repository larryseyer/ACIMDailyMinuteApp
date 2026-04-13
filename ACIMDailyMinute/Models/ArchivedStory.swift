import Foundation
import SwiftData

/// A single archived fact from the ACIM Daily Minute daily log.
///
/// Archive text files on www.acimdailyminute.org are pipe-delimited; each line represents one
/// verified fact along with its sources, ratings, and optional audio reference.
/// `ArchivedStory` is the typed, persisted representation of one of those lines.
///
/// This is the single source of truth for the Archive tab. Views query it directly
/// via `@Query`; search filters it via `#Predicate` on `searchableText`.
@Model
final class ArchivedStory {
    /// Stable content hash used as the unique identity.
    ///
    /// Derived from `dateString + timestamp + factText` via SHA-256 (truncated).
    /// Because the hash is deterministic, re-parsing the same archive file produces
    /// the same IDs, so duplicate inserts are rejected by SwiftData at `save()` time
    /// and repeat ingestion is idempotent.
    @Attribute(.unique) var lineHash: String = ""

    /// `"YYYY-MM-DD"` — the archive day this story belongs to.
    ///
    /// Stored as a String (rather than a `Date`) because `#Predicate` comparisons
    /// on strings are trivial, and lexicographic sort on `YYYY-MM-DD` naturally
    /// matches chronological order.
    var dateString: String = ""

    /// Parsed publication timestamp from the ISO-8601 field at the start of the line.
    /// `nil` when the line's timestamp field was missing or malformed.
    var timestamp: Date?

    /// Source outlet names, split from the comma-separated second field.
    var sources: [String] = []

    /// Accuracy / bias ratings, aligned 1:1 with `sources`.
    var ratings: [String] = []

    /// Source article URLs extracted from the URL field, when present.
    var urls: [String] = []

    /// Hashed mp3 filename from the archive line when the day's format included
    /// an audio reference. The audio itself lives on archive.org; this is just
    /// the pointer, kept so future features can stream or link the recording.
    /// `nil` on older archive lines that predate the audio column.
    var audioFilename: String?

    /// The fact text itself — the last pipe-separated field on the archive line,
    /// regardless of how many metadata columns precede it.
    var factText: String = ""

    /// Concatenation of `factText`, source names, and rating strings, joined by spaces.
    /// Exists as a dedicated field because SwiftData `#Predicate` closures don't play
    /// well with traversals into child arrays — having one flat string to filter
    /// against keeps search queries trivially expressible.
    var searchableText: String = ""

    /// True when the source line's URL field contained a `[CORRECTED]` marker.
    var isCorrected: Bool = false

    init() {}
}
