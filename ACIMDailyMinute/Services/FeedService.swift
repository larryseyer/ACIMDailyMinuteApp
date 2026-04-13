import Foundation
import SwiftData

/// Same two-phase pattern as `DataService`: pure-I/O fetch returns DTOs;
/// MainActor persist writes them through the caller's `ModelContext` so
/// `@Query` observers update without cross-context merge flakiness.
struct FeedService: Sendable {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Returns `nil` if the cooldown blocks the fetch.
    func fetchSourceDTOs(baseURL: String = "https://www.acimdailyminute.org") async throws -> [SourceDTO]? {
        guard FetchCooldown.shouldFetch(
            key: FetchCooldownKey.sources,
            interval: FetchCooldownInterval.nearStatic
        ) else { return nil }

        let url = URL(string: "\(baseURL)/feed.xml")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let parser = FeedXMLParser(data: data)
        return parser.parse()
    }

    @MainActor
    static func persistSources(_ dtos: [SourceDTO], in context: ModelContext) throws {
        for dto in dtos {
            let name = dto.name
            let descriptor = FetchDescriptor<Source>(
                predicate: #Predicate { $0.name == name }
            )
            let existing = try context.fetch(descriptor)

            if let source = existing.first {
                source.accuracy = dto.accuracy
                source.bias = dto.bias
                source.speed = dto.speed
                source.consensus = dto.consensus
                source.controlType = dto.controlType
                source.owner = dto.owner
                source.ownerDisplay = dto.ownerDisplay
            } else {
                let source = Source()
                source.id = dto.name.lowercased().replacingOccurrences(of: " ", with: "-")
                source.name = dto.name
                source.accuracy = dto.accuracy
                source.bias = dto.bias
                source.speed = dto.speed
                source.consensus = dto.consensus
                source.controlType = dto.controlType
                source.owner = dto.owner
                source.ownerDisplay = dto.ownerDisplay
                context.insert(source)
            }
        }
        try context.save()
        FetchCooldown.markFetched(key: FetchCooldownKey.sources)
    }
}

// MARK: - DTO

struct SourceDTO: Sendable {
    let name: String
    let url: String
    let accuracy: Double
    let bias: Double
    let speed: Double
    let consensus: Double
    let controlType: String
    let owner: String
    let ownerDisplay: String
}

// MARK: - XML Parser

final class FeedXMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private let data: Data
    private var sources: [SourceDTO] = []
    private var seenNames: Set<String> = []

    init(data: Data) {
        self.data = data
    }

    func parse() -> [SourceDTO] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = true
        parser.parse()
        return sources
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let isSourceElement = elementName == "source" || qName == "acim:source"

        guard isSourceElement,
              let name = attributeDict["name"],
              !seenNames.contains(name)
        else { return }

        seenNames.insert(name)

        let dto = SourceDTO(
            name: name,
            url: attributeDict["url"] ?? "",
            accuracy: Double(attributeDict["accuracy"] ?? "") ?? 0.0,
            bias: Double(attributeDict["bias"] ?? "") ?? 0.0,
            speed: Double(attributeDict["speed"] ?? "") ?? 0.0,
            consensus: Double(attributeDict["consensus"] ?? "") ?? 0.0,
            controlType: attributeDict["control_type"] ?? "",
            owner: attributeDict["owner"] ?? "",
            ownerDisplay: attributeDict["owner_display"] ?? attributeDict["owner"] ?? ""
        )
        sources.append(dto)
    }
}
