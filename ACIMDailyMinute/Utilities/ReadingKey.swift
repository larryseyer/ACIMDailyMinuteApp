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
///
/// ⛔ **This file imports Foundation and nothing else, and it has to stay that
/// way.** `tools/verify_reading_position.sh` compiles it alone with
/// `ReadingPosition.swift`, so what a ribbon can and cannot name is checkable
/// rather than asserted. Naming a key needs the corpus, so that lives next door
/// in `ReadingKeyNaming.swift`; nothing that reaches `CorpusService`,
/// `WorkbookCatalog` or `CitationResolver` belongs here.
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
}
