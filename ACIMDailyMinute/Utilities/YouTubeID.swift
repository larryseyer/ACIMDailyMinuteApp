import Foundation

/// Pulls the 11-character video ID out of the several URL shapes the feeds and
/// the publisher's own records use: `youtube.com/embed/ID`, `watch?v=ID`, and
/// `youtu.be/ID`.
///
/// Shared by `YouTubePlayerView` (which needs it to build an embed URL) and
/// `LiteYouTubeCard` (which needs it to build a thumbnail URL) so the two cannot
/// disagree about what a given feed link points at.
enum YouTubeID {
    /// Which catalogue a Video-tab day is reading.
    ///
    /// Minute archive JSON ships no `youtube_id`, and the daily JSON can
    /// still name yesterday after today's upload is already in the podcast
    /// feed. Lesson archive rows can keep a dead re-upload after the daily
    /// JSON has the live id.
    enum DayKind {
        case minute
        case lesson
    }

    /// Deduped ids to try, live one first. A 404 thumbnail is not a miss
    /// of the day — `thumbnailAdvance` walks the rest.
    static func candidates(
        kind: DayKind,
        archiveID: String?,
        dailyID: String?,
        podcastIDs: [String]
    ) -> [String] {
        var ids: [String] = []
        func add(_ raw: String?) {
            guard let id = resolve(raw), !ids.contains(id) else { return }
            ids.append(id)
        }
        switch kind {
        case .minute:
            for raw in podcastIDs { add(raw) }
            add(dailyID)
            add(archiveID)
        case .lesson:
            add(dailyID)
            add(archiveID)
            for raw in podcastIDs { add(raw) }
        }
        return ids
    }

    struct ThumbnailAdvance: Equatable {
        var index: Int
        var useFallback: Bool
        var giveUp: Bool
    }

    /// `maxresdefault` is missing on some real uploads, so one miss retries
    /// `hqdefault` of the same id. Both missing means this id is dead.
    static func thumbnailAdvance(
        useFallback: Bool,
        index: Int,
        count: Int
    ) -> ThumbnailAdvance {
        if count <= 0 { return ThumbnailAdvance(index: 0, useFallback: false, giveUp: true) }
        if !useFallback {
            return ThumbnailAdvance(index: index, useFallback: true, giveUp: false)
        }
        let next = index + 1
        if next < count {
            return ThumbnailAdvance(index: next, useFallback: false, giveUp: false)
        }
        return ThumbnailAdvance(index: index, useFallback: true, giveUp: true)
    }

    /// A video id from whatever shape the feed stored: a watch URL, a
    /// youtu.be link, an embed URL, or the bare 11-character id itself.
    static func resolve(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let id = extract(from: trimmed) { return id }
        guard trimmed.count == 11 else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return trimmed
    }

    static func extract(from url: String) -> String? {
        if url.contains("youtube.com/embed/") {
            return normalise(url.components(separatedBy: "embed/").last?.components(separatedBy: "?").first)
        }
        if let range = url.range(of: "v=") {
            let start = range.upperBound
            let end = url[start...].firstIndex(of: "&") ?? url.endIndex
            return normalise(String(url[start..<end]))
        }
        if url.contains("youtu.be/") {
            return normalise(url.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first)
        }
        return nil
    }

    /// A playlist embed (`embed/videoseries?list=…`) parses to the literal
    /// "videoseries", which is not a video and has no thumbnail. Reject it here
    /// rather than letting callers request an image that will 404.
    private static func normalise(_ candidate: String?) -> String? {
        guard let candidate, !candidate.isEmpty, candidate != "videoseries" else { return nil }
        return candidate
    }
}
