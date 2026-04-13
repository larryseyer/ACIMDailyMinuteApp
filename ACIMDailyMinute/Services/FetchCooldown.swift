import Foundation

/// A small utility that gates network fetches by a per-resource cooldown
/// window, stored in `UserDefaults`.
///
/// Each fetchable endpoint in the app has a different natural update cadence:
/// the Daily Minute and Daily Lesson JSON refresh roughly hourly on the server,
/// while `feed.xml` changes only when a new item is published. A single shared
/// interval would either over-poll static data or under-poll live data. Each
/// caller passes the interval that matches the data's real rhythm.
///
/// Cold-start behavior: the foreground views are expected to call `reset(_:)`
/// once per process lifetime so the very first fetch bypasses the cooldown.
/// The cooldown only gates subsequent in-session fetches.
enum FetchCooldown {
    /// Returns `true` if enough time has elapsed since the last successful
    /// fetch for `key` to warrant another network call.
    ///
    /// When the key has never been set, `UserDefaults.double(forKey:)` returns
    /// `0.0`, which makes the elapsed time astronomically large — first-ever
    /// fetches always proceed.
    static func shouldFetch(key: String, interval: TimeInterval) -> Bool {
        let lastFetch = UserDefaults.standard.double(forKey: key)
        return Date().timeIntervalSince1970 - lastFetch >= interval
    }

    /// Records a successful fetch timestamp for `key`. Call only after the
    /// fetch + persist round-trip has fully succeeded — a failed save should
    /// leave the cooldown untouched so the next attempt is not throttled.
    static func markFetched(key: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
    }

    /// Clears cooldown timestamps for one or more keys. Used by pull-to-refresh
    /// and by the cold-start force path so the next `shouldFetch` call returns
    /// `true` regardless of how recently the resource was last fetched.
    static func reset(_ keys: String...) {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}

// MARK: - Keys

/// Centralized cooldown keys so a typo in one call site cannot silently
/// create a parallel, never-read entry in `UserDefaults`.
enum FetchCooldownKey {
    static let dailyMinute = "lastDailyMinuteFetch"
    static let dailyLesson = "lastDailyLessonFetch"
    static let feed = "lastFeedFetch"
    static let archive = "lastArchiveFetch"
}

// MARK: - Intervals

/// Per-resource cooldown intervals, matched to each endpoint's actual update
/// cadence on `acimdailyminute.org`.
enum FetchCooldownInterval {
    /// Daily Minute and Daily Lesson JSON: the server publishes a new entry
    /// daily but may amend within the day. Sampling at 15 minutes guarantees
    /// freshness without overloading GitHub Pages cache.
    static let live: TimeInterval = 15 * 60

    /// `feed.xml`: changes only when new items publish, so a 24-hour
    /// in-session cooldown effectively means "fetch once per session" (cold
    /// start and pull-to-refresh always force a fresh fetch).
    static let nearStatic: TimeInterval = 24 * 60 * 60
}
