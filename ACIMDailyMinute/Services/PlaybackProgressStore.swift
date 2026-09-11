import Foundation

/// Where the reader's listen places live, in `UserDefaults.standard`.
///
/// Kept beside `PlaybackHistory` rather than in SwiftData, for
/// `PlaybackHistory`'s reasons. A new `@Model` has to be added to the
/// `Schema` in *both* the app and the widget's `SharedModelContainer`, and a
/// mismatch there fails the shared container at launch — the widget has no use
/// for a listen place, and no reason to carry the risk of one.
///
/// ⛔ `UserDefaults.standard`, not the App Group: every reader setting in this
/// app lives there, so the widget and the watch can see none of them and
/// CloudKit carries none of them either. A listen place travels **only** in the
/// backup file, like the ribbon and the reminder times.
///
/// This file and `AudioManager` are the only two that touch a listen place.
/// The value, the finished rule, the merge and the activity buckets are all in
/// `PlaybackProgress`, which `tools/verify_playback_progress.sh` compiles alone.
enum PlaybackProgressStore {
    /// Exposed so a view can bind an `@AppStorage` to the same key and be told
    /// when a place moves; the accessors below stay the write path.
    static let defaultsKey = "playbackProgress"

    static var entries: [String: PlaybackProgress] {
        get { PlaybackProgress.decode(UserDefaults.standard.data(forKey: defaultsKey) ?? Data()) }
        set { UserDefaults.standard.set(PlaybackProgress.encode(newValue), forKey: defaultsKey) }
    }

    static func progress(for episodeID: String) -> PlaybackProgress? {
        let id = episodeID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }
        return entries[id]
    }

    /// Moves this episode's place, leaving every other episode's alone.
    static func record(_ progress: PlaybackProgress) {
        var current = entries
        current[progress.episodeID] = progress
        entries = current
    }

    static func clear(_ episodeID: String) {
        let id = episodeID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        var current = entries
        current.removeValue(forKey: id)
        entries = current
    }

    /// Merges another device's listen places in, keeping the later of each.
    static func merge(_ incoming: [String: PlaybackProgress]) {
        entries = PlaybackProgress.merged(entries, incoming)
    }
}
