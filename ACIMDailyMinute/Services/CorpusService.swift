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
    /// Nil for the passages that do not resolve uniquely — front matter and
    /// Workbook closing pages that are genuinely not in the bundled bodies. An
    /// unresolved passage shows its book name instead. It is never guessed.
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
    /// The Video tab needs it: its rows carry the feed's `source_reference`,
    /// which is this identical string, but no segment id to resolve a citation
    /// with. One mapping rather than two that drift.
    ///
    /// ⛔ An unknown value is not quietly called "Text". The pipeline writes
    /// four values today — `Text_A`, `Text_B`, `Workbook`, `Manual` — and a
    /// fifth book arriving would otherwise be labelled as the Text on the Today
    /// and Archive footers, permanently and invisibly. It names the volume
    /// instead, and says so loudly where a developer can hear it.
    static func bookName(forSourcePDF sourcePDF: String) -> String {
        switch sourcePDF {
        case "Manual": return "Manual for Teachers"
        case "Workbook": return "Workbook for Students"
        case "Text_A", "Text_B", "Text": return "Text"
        default:
            // Deliberately not an assertion: the Archive passes the feed's own
            // string through here, so a server-side change would crash every
            // Debug build. The volume's name is true of any book in it, which
            // is the most that can be said without knowing which one.
            return "A Course in Miracles"
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

struct CorpusManualSection: Decodable, Identifiable, Sendable {
    let number: Int
    let title: String
    let body: String

    var id: Int { number }

    var wordCount: Int {
        body.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }

    /// `M-in` for the Introduction; `M-<n>` for a question or a closing.
    var stem: String { number == 0 ? "M-in" : "M-\(number)" }
}

final class CorpusService: @unchecked Sendable {
    static let shared = CorpusService(resourceDirectory: nil)

    let textSections: [CorpusTextSection]
    let textChapters: [CorpusTextChapter]
    let manualSections: [CorpusManualSection]

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

        manualSections = load("ACIMManual.json", as: [CorpusManualSection].self)
    }

    func segment(id: Int) -> CorpusSegment? { segmentsByID[id] }

    /// A Daily Minute cut from the Manual. The structured book is
    /// `manualSection`; this is the word-count slice a saved mark on an old
    /// `manual:<id>` key still names.
    func manualSegment(id: Int) -> CorpusSegment? {
        guard let segment = segmentsByID[id], segment.sourcePDF == "Manual" else { return nil }
        return segment
    }

    func manualSection(_ number: Int) -> CorpusManualSection? {
        manualSections.first { $0.number == number }
    }

    func manualSection(containingSegmentId id: Int) -> CorpusManualSection? {
        guard let citation = segment(id: id)?.parsedCitation,
              case .manual(let number, _) = citation
        else { return nil }
        return manualSection(number)
    }

    func manualSectionBefore(_ number: Int) -> CorpusManualSection? {
        guard let offset = manualSections.firstIndex(where: { $0.number == number }),
              offset > 0
        else { return nil }
        return manualSections[offset - 1]
    }

    func manualSectionAfter(_ number: Int) -> CorpusManualSection? {
        guard let offset = manualSections.firstIndex(where: { $0.number == number }),
              offset + 1 < manualSections.count
        else { return nil }
        return manualSections[offset + 1]
    }

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
