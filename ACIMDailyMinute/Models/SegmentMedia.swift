import Foundation
import SwiftData

/// Durable mapping from a corpus segment to the recordings made for it.
///
/// `ArchivedReading` rows age out of a rolling window, taking their `youtubeID`
/// with them. This table does not age out: it is small, it is the only lasting
/// link between the permanent bundled corpus and the media produced for it over
/// a multi-year publishing run, and losing it cannot be undone from the app.
///
/// Keyed by `segmentId` — a position in the corpus, never a hash of the text.
@Model
final class SegmentMedia {
    @Attribute(.unique) var segmentId: Int = 0
    var youtubeID: String = ""
    var audioURL: String = ""
    /// The feed date this segment was published on, as `yyyy-MM-dd`.
    ///
    /// Never shown to a reader — publication dates are the app's own
    /// bookkeeping. It exists so an annotation made on an archived minute,
    /// which knows only its date, can be rewritten to point at the permanent
    /// corpus segment once that mapping arrives. See
    /// `AnnotationStore.upgradeDateKeys`.
    var publishedDate: String = ""
    var firstSeenAt: Date = Date()

    init() {}
}

extension SegmentMedia {
    /// Upsert. Empty incoming values never overwrite values already recorded —
    /// audio arrives later than video, and a later sighting must not erase it.
    @MainActor
    static func record(
        segmentId: Int,
        youtubeID: String?,
        audioURL: String?,
        publishedDate: String? = nil,
        in context: ModelContext
    ) {
        guard segmentId > 0 else { return }
        let existing = try? context.fetch(
            FetchDescriptor<SegmentMedia>(
                predicate: #Predicate { $0.segmentId == segmentId }
            )
        ).first

        let row = existing ?? {
            let created = SegmentMedia()
            created.segmentId = segmentId
            context.insert(created)
            return created
        }()

        if let youtubeID, !youtubeID.isEmpty { row.youtubeID = youtubeID }
        if let audioURL, !audioURL.isEmpty { row.audioURL = audioURL }
        if let publishedDate, !publishedDate.isEmpty { row.publishedDate = publishedDate }
    }
}
