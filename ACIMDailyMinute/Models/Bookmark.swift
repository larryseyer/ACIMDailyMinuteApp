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
/// last drew, not what the store holds. `@Attribute(.unique)` is the only thing
/// catching the resulting collision today, and it has to come off before
/// SwiftData will accept this store into a CloudKit container.
@Model
final class Bookmark {
    @Attribute(.unique) var itemKey: String = ""
    var channel: String = ""
    var createdAt: Date = Date()

    init() {}
}
