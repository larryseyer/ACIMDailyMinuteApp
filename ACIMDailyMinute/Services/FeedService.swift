import Foundation
import SwiftData

/// Fetches and parses `/feed.xml`. Same two-phase pattern as `DataService`:
/// a pure-I/O fetch returns lightweight DTOs, then a `@MainActor` persist
/// step records the fetch into `FetchCooldown`.
///
/// Unlike `DataService`, the feed does NOT write SwiftData rows. The Daily
/// Minute and Daily Lesson JSON endpoints are the source of truth for
/// content; `feed.xml` is a discovery surface (RSS readers, podcast apps,
/// the in-app archive list in Phase 3.7). Persist exists only so callers
/// can tag the fetch as completed and enforce the per-resource cooldown
/// against the same `FetchCooldown` machinery the JSON services use.
struct FeedService: Sendable {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Returns `nil` if the cooldown window blocks the fetch.
    func fetchFeedItems(baseURL: String = "https://www.acimdailyminute.org") async throws -> [FeedItemDTO]? {
        guard FetchCooldown.shouldFetch(
            key: FetchCooldownKey.feed,
            interval: FetchCooldownInterval.nearStatic
        ) else { return nil }

        let url = URL(string: "\(baseURL)/feed.xml")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let parser = FeedXMLParser(data: data)
        return parser.parse()
    }

    /// Records the successful fetch in `FetchCooldown`. No SwiftData writes —
    /// the JSON services own the canonical content rows. Kept as a separate
    /// `@MainActor` entry point so callers can decide *when* to mark the
    /// cooldown (e.g. after archive UI consumption succeeds, not just on
    /// network success).
    @MainActor
    static func persistFeed(_ items: [FeedItemDTO], in context: ModelContext) throws {
        _ = items
        _ = context
        FetchCooldown.markFetched(key: FetchCooldownKey.feed)
    }
}

// MARK: - DTO

/// One `<item>` in `/feed.xml`. `stream` is `"minute"` or `"lesson"` (the
/// publisher's `<acim:stream>` discriminator). `sourceRef` is reserved for
/// the publisher's optional `<acim:source>` element — currently never
/// emitted, kept optional for forward compatibility.
struct FeedItemDTO: Sendable {
    let guid: String
    let title: String
    let link: String
    let pubDate: String
    let stream: String
    let sourceRef: String?
}

// MARK: - XML Parser

/// `XMLParserDelegate` is callback-based and inherently single-threaded;
/// `@unchecked Sendable` is the standard escape hatch for NSObject delegate
/// types under Swift 6 strict concurrency. Each parser instance is used
/// exactly once on a single task — the `parse()` call.
final class FeedXMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private let data: Data
    private var items: [FeedItemDTO] = []

    private var currentElement: String = ""
    private var currentTitle: String = ""
    private var currentLink: String = ""
    private var currentPubDate: String = ""
    private var currentGuid: String = ""
    private var currentStream: String = ""
    private var currentSourceRef: String? = nil
    private var inItem: Bool = false

    init(data: Data) {
        self.data = data
    }

    func parse() -> [FeedItemDTO] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true
        parser.parse()
        return items
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
            currentLink = ""
            currentPubDate = ""
            currentGuid = ""
            currentStream = ""
            currentSourceRef = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "title":   currentTitle += string
        case "link":    currentLink += string
        case "pubDate": currentPubDate += string
        case "guid":    currentGuid += string
        case "stream":  currentStream += string
        case "source":  currentSourceRef = (currentSourceRef ?? "") + string
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
            let dto = FeedItemDTO(
                guid: currentGuid.trimmingCharacters(in: .whitespacesAndNewlines),
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines),
                stream: currentStream.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceRef: currentSourceRef?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            items.append(dto)
            inItem = false
        }
        currentElement = ""
    }
}
