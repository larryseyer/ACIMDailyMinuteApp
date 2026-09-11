import Foundation

/// Whether a reading has narration or video, keyed the way the feed names it.
///
/// ⛔ **Availability is a feed-driven overlay, never bundled, never computed.**
/// Audio and video are produced about one a day, so most readings will carry
/// neither for the life of this app. The key is `segment:<id>` or `lesson:<n>`.
/// A filename (`2026-09-10.mp3`, `lesson-089.mp3`) is not a key, and matching
/// a body against the corpus is not a key: both invent a pairing the publisher
/// did not state, and both go stale the moment a correction lands.
///
/// Today's `/daily-minute.json` archive entries omit `segment_id`. Until the
/// pipeline emits it, `overlaySegmentId` is nil and the play control stays
/// absent on the Course reading of that passage. Absence is the normal state.
///
/// Pure by design — no SwiftUI, no SwiftData, no `Bundle` — so
/// `tools/verify_media_overlay.sh` can compile it alone.
enum MediaOverlay {
    /// One archive-minute row, as far as the overlay cares.
    ///
    /// Field names match `InlineArchiveMinuteDTO` so a fixture that decodes
    /// here decodes there. Extra JSON keys are ignored; missing optionals
    /// stay nil, which is how today's feed still loads.
    struct ArchiveMinute: Codable, Equatable, Sendable {
        var date: String
        var text: String
        var source_reference: String
        var audio_url: String
        var segment_id: Int?
        var youtube_id: String?

        /// The overlay key, or nil when the feed did not name a segment.
        var overlaySegmentId: Int? { MediaOverlay.overlaySegmentId(segment_id) }
    }

    /// What the play control would draw, once a key has been resolved.
    struct Hit: Equatable, Sendable {
        var audioURL: String
        var youtubeID: String

        /// Tap plays narration. No audio means no Listen button — video is
        /// a long-press, not a second control on the leading edge.
        var showsListen: Bool { !Self.trimmed(audioURL).isEmpty }

        /// Offered in the control's menu, never as its tap.
        var showsWatch: Bool { !Self.trimmed(youtubeID).isEmpty }

        /// Index values win when non-empty; the surface fills the gaps.
        /// Both empty (or whitespace) is no overlay at all.
        static func resolve(
            indexAudio: String?,
            indexVideo: String?,
            surfaceAudio: String?,
            surfaceVideo: String?
        ) -> Hit? {
            let audio = firstNonEmpty(indexAudio, surfaceAudio)
            let video = firstNonEmpty(indexVideo, surfaceVideo)
            if audio.isEmpty && video.isEmpty { return nil }
            return Hit(audioURL: audio, youtubeID: video)
        }

        private static func trimmed(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private static func firstNonEmpty(_ a: String?, _ b: String?) -> String {
            let left = trimmed(a ?? "")
            if !left.isEmpty { return left }
            return trimmed(b ?? "")
        }
    }

    /// A segment id the overlay may key on. Zero and negatives are absent:
    /// `SegmentMedia.record` already refuses them, and treating 0 as a hit
    /// would paint Listen on every unread row that decoded a default.
    static func overlaySegmentId(_ raw: Int?) -> Int? {
        guard let raw, raw > 0 else { return nil }
        return raw
    }
}
