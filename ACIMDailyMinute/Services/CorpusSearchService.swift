import Foundation

/// What one search record names, and how a results row titles it.
struct SearchEntry: Sendable {
    let key: ReadingKey
    let title: String
    let subtitle: String?
}

/// Builds the book's index from the bundle, once, and knows which reading each
/// record is. `CorpusSearch` stays pure; this is the one place that touches
/// `CorpusService`, the catalogs and `ReadingText`.
///
/// An actor so the build — `displayString` over 744 bodies, then the fold —
/// happens off the main thread on the first non-empty query and never again.
actor CorpusSearchService {
    static let shared = CorpusSearchService()

    /// Book order: the Text, then the Workbook with its two Part Introductions
    /// in place, then the Manual. Parallel to `index().records`.
    nonisolated let entries: [SearchEntry]
    private let bodies: [String]
    private var cached: SearchIndex?

    init(corpus: CorpusService = .shared) {
        var entries: [SearchEntry] = []
        var bodies: [String] = []

        for section in corpus.textSections {
            entries.append(SearchEntry(
                key: .textSection(chapter: section.chapterNumber, section: section.sectionNumber),
                title: section.sectionTitle,
                subtitle: section.chapterNumber == 0 ? nil : "Chapter \(section.chapterNumber)"
            ))
            bodies.append(section.body)
        }

        func addIntroduction(_ number: Int) {
            guard let intro = WorkbookBodiesCatalog.introduction(for: number) else { return }
            entries.append(SearchEntry(key: .lesson(number), title: intro.title, subtitle: "Workbook for Students"))
            bodies.append(intro.body)
        }
        func addLessons(_ range: ClosedRange<Int>) {
            for n in range {
                guard let body = WorkbookBodiesCatalog.body(for: n) else { continue }
                entries.append(SearchEntry(
                    key: .lesson(n),
                    title: "Lesson \(n)",
                    subtitle: WorkbookCatalog.title(for: n)
                ))
                bodies.append(body)
            }
        }
        addIntroduction(0)
        addLessons(1...180)
        addIntroduction(500)
        addLessons(181...365)

        for segment in corpus.manual {
            entries.append(SearchEntry(key: .manual(segment.segmentId), title: "Manual for Teachers", subtitle: nil))
            bodies.append(segment.body)
        }

        self.entries = entries
        self.bodies = bodies
    }

    func index() -> SearchIndex {
        if let cached { return cached }
        let records = zip(entries.indices, bodies).map { offset, body in
            SearchRecord(
                id: offset,
                title: entries[offset].title,
                display: ReadingText.displayString(from: body)
            )
        }
        let built = SearchIndex(records: records)
        cached = built
        return built
    }

    /// The scan, on the actor so it never runs on the main thread. Called from
    /// a view's task, `Task.isCancelled` is the caller's, so a superseded query
    /// stops scanning as soon as the next keystroke lands.
    func search(_ rawQuery: String) -> (index: SearchIndex, results: SearchResults) {
        let built = index()
        return (built, built.search(rawQuery, shouldStop: { Task.isCancelled }))
    }

    /// The headings group: a lesson number typed whole, lesson titles, chapter
    /// and section titles. Cheap enough to run on every keystroke, so it is not
    /// isolated to the actor. A single digit is a lesson number even though it
    /// is too short to be a search.
    nonisolated func headings(matching rawQuery: String) -> [SearchEntry] {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var result: [SearchEntry] = []
        if let n = Int(trimmed), (1...365).contains(n) {
            result.append(SearchEntry(key: .lesson(n), title: "Lesson \(n)", subtitle: WorkbookCatalog.title(for: n)))
        }
        guard let query = SearchFold.normalizedQuery(trimmed) else { return result }
        for entry in entries {
            switch entry.key {
            case .lesson(let n) where n == 0 || n == 500:
                if SearchFold.fold(entry.title).contains(query) { result.append(entry) }
            case .lesson:
                if let subtitle = entry.subtitle, SearchFold.fold(subtitle).contains(query) { result.append(entry) }
            case .textSection(let chapter, _):
                let chapterTitle = CorpusService.shared.textChapter(chapter)?.title ?? ""
                if SearchFold.fold(entry.title).contains(query) || SearchFold.fold(chapterTitle).contains(query) {
                    result.append(entry)
                }
            case .manual, .segment, .minuteDate:
                break
            }
        }
        return result
    }
}
