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
    /// The `.minuteDate` name carries no date: publication dates are the app's
    /// own bookkeeping and never appear on a reader-facing surface.
    func displayName(corpus: CorpusService = .shared) -> String {
        switch self {
        case .lesson(let n):
            if let title = WorkbookCatalog.title(for: n) { return "Lesson \(n) — \(title)" }
            return "Lesson \(n)"
        case .segment(let id):
            if let s = corpus.segment(id: id) { return "Daily Minute — \(s.sourcePDF)" }
            return "Daily Minute"
        case .manual:
            return "Manual for Teachers"
        case .textSection(let c, let s):
            if let section = corpus.textSections.first(
                where: { $0.chapterNumber == c && $0.sectionNumber == s }
            ) {
                return "Text, Chapter \(c) — \(section.sectionTitle)"
            }
            return "Text, Chapter \(c)"
        case .minuteDate:
            return "Daily Minute"
        }
    }
}
