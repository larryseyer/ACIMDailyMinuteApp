import Foundation

/// Turns a reading — and optionally a place inside it — into an address.
///
/// The one place that knows which readings have citations and which do not, so
/// no surface has to decide for itself and get it subtly wrong. Separate from
/// `Citation` because it needs `CorpusService` and `WorkbookBodiesCatalog`,
/// and `Citation` stays pure so a harness can compile it alone.
enum CitationResolver {
    /// The address without a paragraph — what a heading shows.
    ///
    /// Nil where the reading has no addressable form: the Manual, and an
    /// archived minute whose segment is not yet known.
    static func stem(for key: ReadingKey, corpus: CorpusService = .shared) -> String? {
        switch key {
        case .textSection(let chapter, let section):
            guard corpus.textSection(chapter: chapter, section: section) != nil else { return nil }
            return chapter == 0 ? "Pref" : "T-\(chapter).\(section)"
        case .lesson(let number):
            switch number {
            case 0: return "W-pI.in"
            case 500: return "W-pII.in"
            case 1...365: return "W-\(number)"
            default: return nil
            }
        case .segment(let id):
            return corpus.segment(id: id)?.parsedCitation?.stem
        case .manual, .minuteDate:
            return nil
        }
    }

    /// The address of the paragraph a `Character` offset falls in.
    ///
    /// Exact for a Text section, a lesson and a Part Introduction: the address
    /// is already known and the paragraph is a count over the string the reader
    /// is looking at.
    ///
    /// A segment is different. Its citation was located at export by matching
    /// its opening words, and refining it by offset would mean assuming the
    /// passage runs contiguously through the Text — which is not always true,
    /// because page furniture is sometimes removed mid-passage. So a segment
    /// cites where it begins, whatever the offset.
    static func citation(
        for key: ReadingKey,
        characterOffset: Int,
        corpus: CorpusService = .shared
    ) -> Citation? {
        switch key {
        case .textSection(let chapter, let section):
            guard let reading = corpus.textSection(chapter: chapter, section: section) else {
                return nil
            }
            let paragraph = Citation.paragraphNumber(
                atCharacterOffset: characterOffset,
                in: ReadingText.displayString(from: reading.body)
            )
            return chapter == 0
                ? .preface(paragraph: paragraph)
                : .text(chapter: chapter, section: section, paragraph: paragraph)

        case .lesson(let number):
            let body: String?
            switch number {
            case 0, 500: body = WorkbookBodiesCatalog.introduction(for: number)?.body
            default: body = WorkbookBodiesCatalog.body(for: number)
            }
            guard let body else { return nil }
            let paragraph = Citation.paragraphNumber(
                atCharacterOffset: characterOffset,
                in: ReadingText.displayString(from: body)
            )
            switch number {
            case 0: return .partIntroduction(part: 1, paragraph: paragraph)
            case 500: return .partIntroduction(part: 2, paragraph: paragraph)
            case 1...365: return .lesson(number: number, paragraph: paragraph)
            default: return nil
            }

        case .segment(let id):
            return corpus.segment(id: id)?.parsedCitation

        case .manual, .minuteDate:
            return nil
        }
    }
}
