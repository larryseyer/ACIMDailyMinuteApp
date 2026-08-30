import Foundation

/// The bundled ACIM corpus: the one tier of content that owes nothing to any
/// network service. Loaded once, held for the process lifetime.
///
/// `resourceDirectory` exists so the corpus can be loaded outside an app bundle.
/// A `swiftc` harness has no `Bundle.main` worth reading, and an integrity check
/// that cannot run is not a check.
struct CorpusSegment: Decodable, Sendable {
    let segmentId: Int
    let sourcePDF: String
    let body: String
}

struct CorpusTextSection: Decodable, Sendable {
    let chapterNumber: Int
    let chapterTitle: String
    let sectionNumber: Int
    let sectionTitle: String
    let body: String
}

private struct ManualEntry: Decodable {
    let segmentId: Int
    let body: String
}

final class CorpusService: @unchecked Sendable {
    static let shared = CorpusService(resourceDirectory: nil)

    let textSections: [CorpusTextSection]
    let manual: [CorpusSegment]

    private let segmentsByID: [Int: CorpusSegment]
    private let orderedSegmentIDs: [Int]

    init(resourceDirectory: URL?) {
        func load<T: Decodable>(_ name: String, as type: [T].Type) -> [T] {
            let url: URL?
            if let resourceDirectory {
                url = resourceDirectory.appendingPathComponent(name)
            } else {
                url = Bundle.main.url(
                    forResource: (name as NSString).deletingPathExtension,
                    withExtension: "json"
                )
            }
            guard let url,
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([T].self, from: data)
            else { return [] }
            return decoded
        }

        textSections = load("ACIMTextSections.json", as: [CorpusTextSection].self)

        let segments = load("ACIMSegments.json", as: [CorpusSegment].self)
        orderedSegmentIDs = segments.map(\.segmentId)
        segmentsByID = Dictionary(uniqueKeysWithValues: segments.map { ($0.segmentId, $0) })

        manual = load("ACIMManual.json", as: [ManualEntry].self)
            .map { CorpusSegment(segmentId: $0.segmentId, sourcePDF: "Manual", body: $0.body) }
    }

    func segment(id: Int) -> CorpusSegment? { segmentsByID[id] }

    var allSegmentIDs: [Int] { orderedSegmentIDs }

    var isEmpty: Bool { segmentsByID.isEmpty && textSections.isEmpty }
}
