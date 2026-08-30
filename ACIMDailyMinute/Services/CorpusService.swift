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
    /// Where this passage begins in the book, derived once at export.
    ///
    /// Nil for every Manual segment, which is bundled as 105 word-count cuts of
    /// a continuous stream with nothing to address, and for the 13 passages that
    /// do not resolve uniquely — front matter and Workbook closing pages that
    /// are genuinely not in the bundled bodies. An unresolved passage shows its
    /// book name instead. It is never guessed.
    let citation: String?
}

extension CorpusSegment {
    var parsedCitation: Citation? {
        citation.flatMap(Citation.init(rawValue:))
    }

    /// What to show when there is no citation. `sourcePDF` is the pipeline's own
    /// name for the source — a reader seeing `Text Part A` learns nothing.
    var bookName: String { Self.bookName(forSourcePDF: sourcePDF) }

    /// The same mapping, reachable without a segment.
    ///
    /// The Archive tab needs it: its rows carry the feed's `source_reference`,
    /// which is this identical string, but no segment id to resolve a citation
    /// with. One mapping rather than two that drift.
    static func bookName(forSourcePDF sourcePDF: String) -> String {
        switch sourcePDF {
        case "Manual": "Manual for Teachers"
        case "Workbook": "Workbook for Students"
        default: "Text"
        }
    }
}

struct CorpusTextSection: Decodable, Sendable {
    let chapterNumber: Int
    let chapterTitle: String
    let sectionNumber: Int
    let sectionTitle: String
    let body: String
}

extension CorpusTextSection {
    /// Roughly what a reader wants to know before opening a section: whether
    /// this is two pages or twenty.
    var wordCount: Int {
        body.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }
}

/// One chapter of the Text, with its sections in reading order.
struct CorpusTextChapter: Identifiable, Sendable {
    let number: Int
    let title: String
    let sections: [CorpusTextSection]

    var id: Int { number }

    /// Chapter 0 is the Preface, which has no number a reader would recognise.
    var displayName: String { number == 0 ? title : "Chapter \(number)" }

    /// The stored title, shown beneath the chapter number. Never re-cased: the
    /// corpus stores chapter titles in capitals, and title-casing
    /// "GOD'S PLAN FOR SALVATION" by rule produces mistakes.
    var subtitle: String? { number == 0 ? nil : title }
}

private struct ManualEntry: Decodable {
    let segmentId: Int
    let body: String
}

final class CorpusService: @unchecked Sendable {
    static let shared = CorpusService(resourceDirectory: nil)

    let textSections: [CorpusTextSection]
    let textChapters: [CorpusTextChapter]
    let manual: [CorpusSegment]

    private let segmentsByID: [Int: CorpusSegment]
    private let orderedSegmentIDs: [Int]
    private let textIndex: [TextAddress: Int]

    private struct TextAddress: Hashable {
        let chapter: Int
        let section: Int
    }

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

        // The export orders by chapter then section, so first-seen order is
        // reading order and no sort is needed — or wanted, since a sort would
        // quietly paper over an export that had stopped being ordered.
        var chapterOrder: [Int] = []
        var chapterTitles: [Int: String] = [:]
        var grouped: [Int: [CorpusTextSection]] = [:]
        var index: [TextAddress: Int] = [:]
        for (offset, section) in textSections.enumerated() {
            index[TextAddress(chapter: section.chapterNumber, section: section.sectionNumber)] = offset
            if grouped[section.chapterNumber] == nil {
                chapterOrder.append(section.chapterNumber)
                chapterTitles[section.chapterNumber] = section.chapterTitle
            }
            grouped[section.chapterNumber, default: []].append(section)
        }
        textIndex = index
        textChapters = chapterOrder.map {
            CorpusTextChapter(
                number: $0,
                title: chapterTitles[$0] ?? "",
                sections: grouped[$0] ?? []
            )
        }

        let segments = load("ACIMSegments.json", as: [CorpusSegment].self)
        orderedSegmentIDs = segments.map(\.segmentId)
        segmentsByID = Dictionary(uniqueKeysWithValues: segments.map { ($0.segmentId, $0) })

        manual = load("ACIMManual.json", as: [ManualEntry].self)
            .map { CorpusSegment(segmentId: $0.segmentId, sourcePDF: "Manual", body: $0.body, citation: nil) }
    }

    func segment(id: Int) -> CorpusSegment? { segmentsByID[id] }

    func textChapter(_ number: Int) -> CorpusTextChapter? {
        textChapters.first { $0.number == number }
    }

    func textSection(chapter: Int, section: Int) -> CorpusTextSection? {
        guard let offset = textIndex[TextAddress(chapter: chapter, section: section)] else { return nil }
        return textSections[offset]
    }

    /// The next section in reading order, crossing into the following chapter.
    /// Nil at the end of the book — which is what lets a reader read the Text
    /// straight through instead of walking back up two levels between every
    /// section.
    func sectionAfter(chapter: Int, section: Int) -> CorpusTextSection? {
        guard let offset = textIndex[TextAddress(chapter: chapter, section: section)],
              textSections.indices.contains(offset + 1)
        else { return nil }
        return textSections[offset + 1]
    }

    func sectionBefore(chapter: Int, section: Int) -> CorpusTextSection? {
        guard let offset = textIndex[TextAddress(chapter: chapter, section: section)],
              offset > 0
        else { return nil }
        return textSections[offset - 1]
    }

    var allSegmentIDs: [Int] { orderedSegmentIDs }

    var isEmpty: Bool { segmentsByID.isEmpty && textSections.isEmpty }
}
