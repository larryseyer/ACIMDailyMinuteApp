import Foundation

/// Where the reader got to in a recording — the Listen equivalent of a ribbon.
///
/// `PlaybackHistory` only records that an episode was opened. `AudioManager.currentTime`
/// is in-memory and dies with the session. Without this value there is no
/// "part-finished", and Listen cannot be activity: it can only be a catalogue
/// of feeds, which is the Course organised a second time (Read already does that).
///
/// A pure value: no SwiftUI, no SwiftData, no `UserDefaults`, no `Bundle`, no
/// `AudioManager`, no `Date()`. `tools/verify_playback_progress.sh` compiles this
/// file and nothing else, so the purity is not a convention anyone has to remember:
/// breaking it breaks the check.
struct PlaybackProgress: Codable, Equatable, Sendable {
    /// Remaining time at or below which a recording is finished, not paused.
    ///
    /// Two seconds rather than a percentage: a Daily Minute is about a minute,
    /// and 95% of 60s would still leave the reader three seconds from the end.
    /// Sitting on the last frame is the television bug this number exists to
    /// prevent on Listen too.
    static let finishedRemaining: Double = 2.0

    /// Below this, a position is a blip — opening the file, not listening.
    /// Resume starts over; the row is not part-finished.
    static let startedThreshold: Double = 1.0

    /// The file this travels in records milliseconds, so two devices comparing
    /// the same moment must compare it at that resolution. Full-precision `<`
    /// would make a device re-importing its own backup find every place a
    /// fraction older than the one it holds, and the merge would stop being
    /// commutative.
    static let timeResolution: TimeInterval = 0.001

    /// The feed's own episode id, or — when a reading is played without one —
    /// the resolved remote URL. Empty is refused at `make`, so a row on disk
    /// always names something Listen can find again.
    var episodeID: String
    /// Seconds into the recording. Never a fraction of duration: a percentage
    /// would lie the moment two devices disagreed about how long the file was.
    var position: Double
    /// Seconds, 0 when the file has not reported a length yet.
    var duration: Double
    var updatedAt: Date

    /// True when the recording has been heard through. A finished place
    /// resumes at the start, not on its last frame.
    var isFinished: Bool {
        duration > 0 && (duration - position) <= Self.finishedRemaining
    }

    /// True when there is a place to resume that is not the start and not the end.
    var isInProgress: Bool {
        !isFinished && position >= Self.startedThreshold
    }

    // MARK: - Making one

    /// A place in a recording, or nil where recording one would lie.
    ///
    /// An empty id is refused: nothing could ever find it again. A non-finite
    /// number is refused: it cannot be a place. A position past the end is
    /// clamped rather than refused, so playing through still leaves a finished
    /// row rather than evaporating.
    static func make(
        episodeID: String,
        position: Double,
        duration: Double,
        at now: Date
    ) -> PlaybackProgress? {
        let id = episodeID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }
        guard position.isFinite, duration.isFinite, duration >= 0 else { return nil }
        let clamped: Double
        if duration > 0 {
            clamped = min(max(0, position), duration)
        } else {
            clamped = max(0, position)
        }
        return PlaybackProgress(
            episodeID: id,
            position: clamped,
            duration: duration,
            updatedAt: now
        )
    }

    /// Seconds to seek to, or nil to start at the beginning.
    ///
    /// Finished starts over. A blip starts over. Missing progress starts over.
    /// Only a real mid-point resumes.
    static func resumePosition(_ progress: PlaybackProgress?) -> Double? {
        guard let progress, progress.isInProgress else { return nil }
        return progress.position
    }

    // MARK: - Two devices

    /// True when `self` is the later of two places for one episode.
    ///
    /// A total order, not just a date comparison: equal moments fall through to
    /// the position, so the merge below is commutative and associative even when
    /// a reader's two devices stamp the same millisecond.
    func isLater(than other: PlaybackProgress) -> Bool {
        let mine = (updatedAt.timeIntervalSinceReferenceDate / Self.timeResolution).rounded()
        let theirs = (other.updatedAt.timeIntervalSinceReferenceDate / Self.timeResolution).rounded()
        if mine != theirs { return mine > theirs }
        if position != other.position { return position > other.position }
        return episodeID > other.episodeID
    }

    /// The union of two devices' listen places, episode by episode, keeping the
    /// later of each.
    ///
    /// A merge here has a meaning — the later place is where the reader actually
    /// got to — which is why this travels with the listened history rather than
    /// with the scalars.
    ///
    /// ⛔ It can never move an episode's place backwards, which is the same promise
    /// `BackupMerge` makes about a reader's words: an import may add to what this
    /// device knows and may never take from it.
    static func merged(
        _ mine: [String: PlaybackProgress],
        _ theirs: [String: PlaybackProgress]
    ) -> [String: PlaybackProgress] {
        var result = mine
        for (episode, incoming) in theirs {
            guard let existing = result[episode] else {
                result[episode] = incoming
                continue
            }
            if incoming.isLater(than: existing) { result[episode] = incoming }
        }
        return result
    }

    // MARK: - At rest

    /// The stored form: episode id → place. Keyed the same way on disk and in
    /// the backup file, so a round trip cannot rename a listening.
    static func decode(_ data: Data) -> [String: PlaybackProgress] {
        guard !data.isEmpty,
              let decoded = try? JSONDecoder().decode([String: PlaybackProgress].self, from: data)
        else { return [:] }
        return decoded.filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func encode(_ entries: [String: PlaybackProgress]) -> Data {
        (try? JSONEncoder().encode(entries)) ?? Data()
    }
}

/// Which activity bucket a Listen row belongs to.
///
/// Exclusive, in this order: now playing, part-finished, finished, downloaded.
/// An unplayed, undownloaded episode is `nil` — that is a catalogue entry, and
/// the Course is organised exactly once, in Read.
enum ListenActivity: String, Equatable, Sendable {
    case nowPlaying
    case inProgress
    case downloaded
    case finished

    static func classify(
        isActive: Bool,
        progress: PlaybackProgress?,
        listenedAt: Date?,
        isDownloaded: Bool
    ) -> ListenActivity? {
        if isActive { return .nowPlaying }
        if progress?.isInProgress == true { return .inProgress }
        if progress?.isFinished == true { return .finished }
        if listenedAt != nil { return .finished }
        if isDownloaded { return .downloaded }
        return nil
    }
}
