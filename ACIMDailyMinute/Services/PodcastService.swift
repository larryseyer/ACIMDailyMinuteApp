import Foundation

struct PodcastEpisode: Sendable, Identifiable {
    let id: String
    let title: String
    let date: Date
    let audioURL: String
    let duration: String
}

actor PodcastService {
    /// Fetches and parses `podcast.xml`, returning episodes sorted newest first.
    ///
    /// GitHub Pages serves `podcast.xml` with `Cache-Control: max-age=600`, so
    /// within a 10-minute window `URLSession.shared` will happily return the
    /// cached response without even revalidating against the origin. That
    /// behaviour is what we want for the passive on-appear fetch, but it is
    /// actively wrong for a cold start or a pull-to-refresh — which is exactly
    /// when the newly-published daily digest needs to show up.
    ///
    /// Pass `force: true` in those cases: the request uses
    /// `.reloadRevalidatingCacheData`, which sends `If-None-Match` /
    /// `If-Modified-Since` and accepts a 304 fast path when the feed is
    /// unchanged. We get the freshness guarantee without re-downloading 68 KB
    /// of XML on every refresh.
    func fetchEpisodes(baseURL: String = "https://www.acimdailyminute.org", force: Bool = false) async throws -> [PodcastEpisode] {
        let url = URL(string: "\(baseURL)/podcast.xml")!
        let request = URLRequest(
            url: url,
            cachePolicy: force ? .reloadRevalidatingCacheData : .useProtocolCachePolicy
        )
        let (data, _) = try await URLSession.shared.data(for: request)
        let parser = PodcastXMLParser(data: data)
        return parser.parse().sorted { $0.date > $1.date }
    }

    func fetchYouTubeURL(baseURL: String = "https://www.acimdailyminute.org") async throws -> String? {
        let url = URL(string: "\(baseURL)/monitor.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let monitor = try JSONDecoder().decode(MonitorResponse.self, from: data)
        return monitor.dailyDigest?.youtubeURL
    }

    private static let playlistID = "PLm8mlmJgzmMfqH8YkhdRVFET200vZGRWN"

    func fetchYouTubePlaylist() async throws -> [String: String] {
        let url = URL(string: "https://www.youtube.com/playlist?list=\(Self.playlistID)")!
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return [:] }

        // Parse videoId and title pairs from playlist page
        var dateToVideoURL: [String: String] = [:]
        let videoIDs = matches(in: html, pattern: #""videoId":"([^"]+)""#)
        let titles = matches(in: html, pattern: #""title":\{"runs":\[\{"text":"([^"]+)"\}"#)

        let uniqueVideoIDs = videoIDs.uniqued()

        for (videoID, title) in zip(uniqueVideoIDs, titles) {
            // Title format: "ACIM Daily Minute Daily Digest - YYYY-MM-DD"
            if let dateRange = title.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) {
                let dateString = String(title[dateRange])
                dateToVideoURL[dateString] = "https://youtube.com/watch?v=\(videoID)"
            }
        }
        return dateToVideoURL
    }

    private func matches(in string: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(string.startIndex..., in: string)
        return regex.matches(in: string, range: range).compactMap { match in
            guard let captureRange = Range(match.range(at: 1), in: string) else { return nil }
            return String(string[captureRange])
        }
    }
}

// MARK: - Array Extension

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Monitor DTO

struct MonitorResponse: Codable, Sendable {
    let dailyDigest: DailyDigestInfo?

    enum CodingKeys: String, CodingKey {
        case dailyDigest = "daily_digest"
    }
}

struct DailyDigestInfo: Codable, Sendable {
    let youtubeURL: String?

    enum CodingKeys: String, CodingKey {
        case youtubeURL = "youtube_url"
    }
}

// MARK: - Podcast XML Parser

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
