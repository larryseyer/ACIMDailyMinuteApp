import Foundation
import SwiftData

/// SwiftData-backed cache for podcast episodes. Listen tab used to hold
/// episodes in view-local `@State`, which meant every cold relaunch drew
/// an empty list until the network came back. Persisting them here lets
/// `@Query` hydrate the list instantly and lets `PodcastService` upsert
/// fresh episodes in the background.
///
/// The `channel` string ("minute" | "lesson") mirrors `PodcastFeed.rawValue`
/// in `ListenView` — both feeds share one SQLite table, filtered at query
/// time rather than split into two models. `lastSeenAt` drives a 30-day
/// TTL purge in `PodcastService.persist` so feeds that drop an episode
/// (or rename its GUID) don't accumulate ghosts.
@Model
final class CachedPodcastEpisode {
    @Attribute(.unique) var id: String = ""
    var channel: String = ""
    var title: String = ""
    var audioURL: String = ""
    var publishedAt: Date = Date()
    var duration: String = ""
    var lastSeenAt: Date = Date()

    init() {}
}
