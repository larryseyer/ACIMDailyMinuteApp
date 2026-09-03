import Foundation

/// When the reader last opened each Listen episode, keyed by the feed's own
/// episode id.
///
/// Kept in `UserDefaults` alongside the reader's other settings rather than in
/// SwiftData for two reasons. `CachedPodcastEpisode` is purged on a 30-day TTL, so listened
/// state stored on that row would quietly evaporate for anything older than a
/// month. And a new `@Model` has to be added to the `Schema` in *both* the app
/// and the widget's `SharedModelContainer` — a mismatch there fails the shared
/// container at launch, and the widget has no use for listened state anyway.
enum PlaybackHistory {
    /// Exposed so views can bind an `@AppStorage` to the same key and get
    /// change notifications; the static accessors below stay the write path.
    static let defaultsKey = "listenedEpisodes"

    /// episode id → the moment it was last opened.
    static var entries: [String: Date] {
        get {
            guard let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let decoded = try? JSONDecoder().decode([String: Date].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    static func playedAt(_ episodeID: String) -> Date? {
        entries[episodeID]
    }

    /// Records `episodeID` as listened. Re-opening an episode refreshes the
    /// timestamp — the row reads "when you listened", and the most recent listen
    /// is the truthful answer to that.
    static func markPlayed(_ episodeID: String, at date: Date = Date()) {
        guard !episodeID.isEmpty else { return }
        var current = entries
        current[episodeID] = date
        entries = current
    }

    static func clear(_ episodeID: String) {
        var current = entries
        current.removeValue(forKey: episodeID)
        entries = current
    }

    static func toggle(_ episodeID: String) {
        if playedAt(episodeID) == nil {
            markPlayed(episodeID)
        } else {
            clear(episodeID)
        }
    }
}
