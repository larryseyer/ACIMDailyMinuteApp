import Foundation

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
        return parser.parse().sorted { $0.date > $1.date }
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
            let date = parseRFC2822Date(currentDate.trimmingCharacters(in: .whitespacesAndNewlines))
            let episode = PodcastEpisode(
                id: currentAudioURL,
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date ?? Date(),
                audioURL: currentAudioURL.trimmingCharacters(in: .whitespacesAndNewlines),
                duration: currentDuration.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if !episode.audioURL.isEmpty {
                episodes.append(episode)
            }
        }
        currentElement = ""
    }

    private func parseRFC2822Date(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: string)
    }
}
