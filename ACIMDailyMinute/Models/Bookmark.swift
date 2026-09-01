import Foundation
import SwiftData

/// Unified bookmark across both ACIM content streams.
///
/// `itemKey` is a composite identifier:
/// - `"minute:{segmentHash}"` for a `DailyMinute` entry
/// - `"lesson:{lessonNumber}"` for a `DailyLesson` entry
///
/// The composite key lets a single `@Query` render the Saved tab without needing
/// a polymorphic association.
///
/// ⛔ Write one only through `BookmarkStore`, never by inserting here. `itemKey`
/// is this model's whole identity — there is no `id` — and a view that decides
/// whether a row exists by searching its own `@Query` snapshot is reading what it
/// last drew, not what the store holds.
///
/// ⛔ **`@Attribute(.unique)` is gone from `itemKey`**, because SwiftData refuses
/// it in a CloudKit-backed store and this model now lives in `reader.store`.
/// Nothing in the database prevents two rows naming one passage any more —
/// `BookmarkIdentity` does, and `BookmarkStore` is the only thing allowed to
/// apply it. That is why every write and every delete goes through the store:
/// a raw `delete` that removes one row of a pair leaves the passage saved after
/// the reader un-saved it, silently.
@Model
final class Bookmark {
    var itemKey: String = ""
    var channel: String = ""
    var createdAt: Date = Date()

    init() {}
}
