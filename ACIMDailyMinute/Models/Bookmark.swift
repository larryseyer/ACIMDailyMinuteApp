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
@Model
final class Bookmark {
    @Attribute(.unique) var itemKey: String = ""
    var channel: String = ""
    var createdAt: Date = Date()

    init() {}
}
