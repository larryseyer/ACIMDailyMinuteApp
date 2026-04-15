import Foundation
import SwiftData

/// Typed errors the podcast pipeline surfaces to the view. Partial payloads
/// come back with the error so the view can decide to show stale-but-real
/// episodes alongside a "something's off with the feed" hint rather than
/// silently discarding a recoverable fetch.
enum PodcastError: Error {
    /// XML parser emitted an error *and* parsed fewer than the one-week
    /// min-trust threshold (7 episodes). View should show a retry state.
    case unparseableFeed(partial: [PodcastEpisode])
}

/// One episode parsed from a podcast RSS feed. The audio URL is also used as
/// the stable `id` since RSS doesn't ship a guaranteed-unique GUID and the
/// enclosure URL is the natural primary key (it's what the audio player
/// streams from).
struct PodcastEpisode: Sendable, Identifiable {
    let id: String
    let title: String
    let date: Date
    let audioURL: String
    let duration: String
}

extension CachedPodcastEpisode {
    /// Re-hydrates the SwiftData cache row as the plain `PodcastEpisode`
    /// struct the row + audio layers speak. Lives here rather than on the
    /// `@Model` file because Widget + Watch targets compile the cache
    /// type too, and they don't carry `PodcastEpisode`.
    func asEpisode() -> PodcastEpisode {
        PodcastEpisode(
            id: id,
            title: title,
            date: publishedAt,
            audioURL: audioURL,
            duration: duration
        )
    }
}

/// Fetches and parses the two ACIM podcast feeds:
/// `/podcast-minute.xml` (one-minute readings) and `/podcast-lessons.xml`
/// (365 Workbook Lessons). Each feed is independent so they're modeled as
/// separate methods rather than one call with a discriminator parameter —
/// callers always know which feed they want.
///
/// `actor` because each fetch reuses no state but we want a single
/// serialized owner for the (eventual) per-feed memo cache. For now the
/// methods are stateless; the actor still gives us a Sendable boundary
/// without sprinkling `@unchecked Sendable` on a reference type.
actor PodcastService {
    /// GitHub Pages serves the podcast feeds with `Cache-Control: max-age=600`.
    /// Within that 10-minute window `URLSession.shared` will return cached
    /// data without revalidating against origin. That's fine for passive
    /// on-appear loads but wrong for a cold start or pull-to-refresh, when
    /// the user expects to see today's freshly-published episode.
    ///
    /// Pass `force: true` from those code paths: the request switches to
    /// `.reloadRevalidatingCacheData`, which sends `If-None-Match` /
    /// `If-Modified-Since` and accepts a 304 fast path when the feed is
    /// unchanged. Freshness without re-downloading the whole XML.
    func fetchMinuteEpisodes(
        baseURL: String = "https://www.acimdailyminute.org",
        force: Bool = false
    ) async throws -> [PodcastEpisode] {
        try await fetch(path: "/podcast-minute.xml", baseURL: baseURL, force: force)
    }

    /// Same shape as `fetchMinuteEpisodes`, but for the lessons feed.
    func fetchLessonEpisodes(
        baseURL: String = "https://www.acimdailyminute.org",
        force: Bool = false
    ) async throws -> [PodcastEpisode] {
        try await fetch(path: "/podcast-lessons.xml", baseURL: baseURL, force: force)
    }

    private func fetch(path: String, baseURL: String, force: Bool) async throws -> [PodcastEpisode] {
        let url = URL(string: "\(baseURL)\(path)")!
        let request = URLRequest(
            url: url,
            cachePolicy: force ? .reloadRevalidatingCacheData : .useProtocolCachePolicy
        )
        let (data, _) = try await URLSession.shared.data(for: request)
        let parser = PodcastXMLParser(data: data)
        let episodes = parser.parse().sorted { $0.date > $1.date }

        // Min-trust threshold: if the parser tripped an error *and* we got
        // fewer than a week of episodes, treat the feed as unreadable so
        // the view can prompt a retry. If we got at least 7 items the feed
        // is probably healthy and the error was a trailing-garbage blip —
        // return what we have rather than hiding recoverable data.
        if parser.didError && episodes.count < 7 {
            throw PodcastError.unparseableFeed(partial: episodes)
        }
        return episodes
    }

    /// Upserts fetched episodes into the SwiftData `CachedPodcastEpisode`
    /// table, keyed by `PodcastEpisode.id` (the enclosure URL). Anything
    /// whose `lastSeenAt` is older than 30 days is purged in the same
    /// pass — feeds that drop or rename episodes would otherwise
    /// accumulate ghosts since unique-key collisions wouldn't fire.
    ///
    /// Static + `@MainActor` because `ModelContext` isn't `Sendable` and
    /// the actor's isolation doesn't help here. Callers from the Listen
    /// tab already run on the main actor.
    @MainActor
    static func persist(
        _ episodes: [PodcastEpisode],
        channel: String,
        in context: ModelContext
    ) throws {
        let now = Date()
        for ep in episodes {
            let id = ep.id
            let descriptor = FetchDescriptor<CachedPodcastEpisode>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try context.fetch(descriptor).first {
                existing.title = ep.title
                existing.audioURL = ep.audioURL
                existing.publishedAt = ep.date
                existing.duration = ep.duration
                existing.channel = channel
                existing.lastSeenAt = now
            } else {
                let model = CachedPodcastEpisode()
                model.id = ep.id
                model.channel = channel
                model.title = ep.title
                model.audioURL = ep.audioURL
                model.publishedAt = ep.date
                model.duration = ep.duration
                model.lastSeenAt = now
                context.insert(model)
            }
        }

        let thirtyDays: TimeInterval = 30 * 24 * 60 * 60
        let cutoff = now.addingTimeInterval(-thirtyDays)
        let staleDescriptor = FetchDescriptor<CachedPodcastEpisode>(
            predicate: #Predicate { $0.lastSeenAt < cutoff }
        )
        let stale = try context.fetch(staleDescriptor)
        for s in stale { context.delete(s) }

        try context.save()
    }
}

// MARK: - Podcast XML Parser

/// `XMLParserDelegate` is callback-based and inherently single-threaded;
/// `@unchecked Sendable` is the standard escape hatch for NSObject delegate
/// types under Swift 6 strict concurrency. Each parser instance is used
/// exactly once on a single task — the `parse()` call.
final class PodcastXMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private let data: Data
    private var episodes: [PodcastEpisode] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDate = ""
    private var currentAudioURL = ""
    private var currentDuration = ""
    private var inItem = false
    /// Set by `parserErrorOccurred` / `validationErrorOccurred`. Read by
    /// `PodcastService.fetch` to decide whether the min-trust threshold
    /// gate should fire.
    private(set) var didError = false

    init(data: Data) {
        self.data = data
    }

    func parse() -> [PodcastEpisode] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return episodes
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName

        if elementName == "item" {
            inItem = true
            currentTitle = ""
            currentDate = ""
            currentAudioURL = ""
            currentDuration = ""
        } else if elementName == "enclosure" && inItem {
            currentAudioURL = attributeDict["url"] ?? ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "pubDate": currentDate += string
        case "itunes:duration": currentDuration += string
        default: break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item" {
            inItem = false
            // Drop-don't-fabricate: an unparseable pubDate used to fall
            // back to `Date()`, which silently surfaced the item as if
            // it were fresh today. Skip the item instead so the feed
            // stays honest; the min-trust threshold in `fetch` still
            // catches the "whole feed broke" case.
            guard let date = parseRFC2822Date(currentDate.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                currentElement = ""
                return
            }
            let episode = PodcastEpisode(
                id: currentAudioURL,
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date,
                audioURL: currentAudioURL.trimmingCharacters(in: .whitespacesAndNewlines),
                duration: currentDuration.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if !episode.audioURL.isEmpty {
                episodes.append(episode)
            }
        }
        currentElement = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        didError = true
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        didError = true
    }

    private func parseRFC2822Date(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: string)
    }
}
