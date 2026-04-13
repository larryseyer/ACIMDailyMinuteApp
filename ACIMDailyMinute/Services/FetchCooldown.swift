import Foundation

/// A small utility that gates network fetches by a per-resource cooldown
/// window, stored in `UserDefaults`.
///
/// Each fetchable endpoint in the app has a different natural update cadence:
/// stories and corrections refresh every 30 minutes on the server, source
/// metadata (`feed.xml`) changes rarely, and the daily digest publishes once
/// per day at 00:00 GMT. A single shared interval would either over-poll
/// static data or under-poll live data. Instead, each caller passes the
/// interval that matches the data's real rhythm.
///
/// Cold-start behavior: `StoriesView` passes `force: true` on its first
/// `.task` invocation per process lifetime, bypassing the cooldown via
/// `reset(_:...)`. The cooldown only gates subsequent in-session fetches.
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
    static let stories = "lastStoriesFetch"
    static let corrections = "lastCorrectionsFetch"
    static let sources = "lastSourcesFetch"
}

// MARK: - Intervals

/// Per-resource cooldown intervals, matched to each endpoint's actual update
/// cadence on `www.acimdailyminute.org`.
enum FetchCooldownInterval {
    /// Stories and corrections: the server publishes new entries roughly
    /// every 30 minutes, so sampling at half the cadence guarantees we catch
    /// new content within one cycle.
    static let live: TimeInterval = 15 * 60

    /// Source metadata in `feed.xml`: near-static, changes on the order of
    /// weeks. A 24-hour in-session cooldown effectively means "fetch once per
    /// session" (cold start and pull-to-refresh always force a fresh fetch).
    static let nearStatic: TimeInterval = 24 * 60 * 60
}
