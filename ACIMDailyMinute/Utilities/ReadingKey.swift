import Foundation

/// Where a reading sits, never what it says.
///
/// Deliberately not `Bookmark.itemKey`. That scheme keys a minute by
/// `sha256("minute:\(segment_id)|\(date)|\(text)")` — a hash folding in the body —
/// which is the pattern behind three duplicate-row bugs here, and Today and
/// Archive disagree about the same reading besides. Annotations sidestep both by
/// naming a position instead.
///
/// `segment` and `manual` point into the bundled corpus, so an annotation still
/// finds its words after every network service this app uses has ended.
enum ReadingKey: Hashable, Sendable {
    case segment(Int)
    case lesson(Int)
    case textSection(chapter: Int, section: Int)
    case manual(Int)
    /// Fallback only: an archived minute whose segment is not yet known.
    /// `AnnotationStore.upgradeDateKeys` promotes these as the mapping arrives.
    case minuteDate(String)

    var rawValue: String {
        switch self {
        case .segment(let id): "segment:\(id)"
        case .lesson(let n): "lesson:\(n)"
        case .textSection(let c, let s): "text:\(c).\(s)"
        case .manual(let id): "manual:\(id)"
        case .minuteDate(let d): "minute-date:\(d)"
        }
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let value = parts[1]
        switch parts[0] {
        case "segment": guard let i = Int(value) else { return nil }; self = .segment(i)
        case "lesson": guard let i = Int(value) else { return nil }; self = .lesson(i)
        case "manual": guard let i = Int(value) else { return nil }; self = .manual(i)
        case "minute-date": guard !value.isEmpty else { return nil }; self = .minuteDate(value)
        case "text":
            let n = value.split(separator: ".").map(String.init)
            guard n.count == 2, let c = Int(n[0]), let s = Int(n[1]) else { return nil }
            self = .textSection(chapter: c, section: s)
        default: return nil
        }
    }

    /// How this reading is named in an export a stranger has to be able to read.
    ///
    /// The stem in parentheses is the address — the one part of this line that
    /// still means something to someone holding the printed book, or reading the
    /// export years after this app is gone. Readings with no addressable form
    /// (the Manual, an archived minute whose segment is unknown) carry no stem
    /// rather than a plausible-looking one.
    ///
    /// The `.minuteDate` name carries no date: publication dates are the app's
    /// own bookkeeping and never appear on a reader-facing surface.
    func displayName(corpus: CorpusService = .shared) -> String {
        let base: String
        switch self {
        case .lesson(0), .lesson(500):
            // The two Part Introductions are keyed as lessons because that is
            // where their annotations already store, but they are not lessons and
            // naming them "Lesson 0" and "Lesson 500" — which this line did — is
            // wrong on the Saved row and wrong forever in an export. The title
            // comes from the corpus rather than a literal, so the row and the
            // screen cannot disagree.
            let number = if case .lesson(let n) = self { n } else { 0 }
            base = WorkbookBodiesCatalog.introduction(for: number)?.title
                ?? "Workbook Introduction"
        case .lesson(let n):
            if let title = WorkbookCatalog.title(for: n) {
                base = "Lesson \(n) — \(title)"
            } else {
                base = "Lesson \(n)"
            }
        case .segment(let id):
            base = "Daily Minute — \(corpus.segment(id: id)?.bookName ?? "A Course in Miracles")"
        case .manual:
            base = "Manual for Teachers"
        case .textSection(let c, let s):
            let chapter = c == 0 ? "Preface" : "Chapter \(c)"
            if let section = corpus.textSection(chapter: c, section: s) {
                base = "Text, \(chapter) — \(section.sectionTitle)"
            } else {
                base = "Text, \(chapter)"
            }
        case .minuteDate:
            base = "Daily Minute"
        }
        guard let stem = CitationResolver.stem(for: self, corpus: corpus) else { return base }
        return "\(base) (\(stem))"
    }
}
