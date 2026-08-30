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
            // Gated on the body existing, exactly as `.textSection` is above and
            // as `citation` is below. A stem that appears for a reading whose
            // address `citation` then refuses is the kind of disagreement that
            // shows up as a heading naming a place no export can cite.
            switch number {
            case 0, 500:
                guard WorkbookBodiesCatalog.introduction(for: number) != nil else { return nil }
                return number == 0 ? "W-pI.in" : "W-pII.in"
            case 1...365:
                guard WorkbookBodiesCatalog.body(for: number) != nil else { return nil }
                return "W-\(number)"
            default: return nil
            }
        case .segment(let id):
            return corpus.segment(id: id)?.parsedCitation?.stem
        case .manual, .minuteDate:
            return nil
        }
    }

    /// The string a paragraph number is counted over — the exact text the
    /// reader is looking at — or nil where the reading has no addressable form.
    ///
    /// Separate from `citation` because building it is three regex passes over
    /// a whole section, and an export names every highlight in the app at once.
    /// A caller with many offsets in one reading builds this once and counts
    /// over it many times; `CitationResolver.citation(for:characterOffset:)`
    /// is the same rule for a caller with one.
    static func displayString(
        for key: ReadingKey,
        corpus: CorpusService = .shared
    ) -> String? {
        switch key {
        case .textSection(let chapter, let section):
            guard let reading = corpus.textSection(chapter: chapter, section: section) else {
                return nil
            }
            return ReadingText.displayString(from: reading.body)

        case .lesson(let number):
            let body: String?
            switch number {
            case 0, 500: body = WorkbookBodiesCatalog.introduction(for: number)?.body
            case 1...365: body = WorkbookBodiesCatalog.body(for: number)
            default: body = nil
            }
            guard let body else { return nil }
            return ReadingText.displayString(from: body)

        case .segment, .manual, .minuteDate:
            // A segment cites where it begins and never counts paragraphs; the
            // other two have no addressable form at all.
            return nil
        }
    }

    /// The address of the paragraph a `Character` offset falls in, counted over
    /// a display string the caller already holds.
    ///
    /// Exact for a Text section, a lesson and a Part Introduction: the address
    /// is already known and the paragraph is a count over the string the reader
    /// is looking at.
    static func citation(
        for key: ReadingKey,
        characterOffset: Int,
        displayString: String
    ) -> Citation? {
        let paragraph = Citation.paragraphNumber(
            atCharacterOffset: characterOffset,
            in: displayString
        )
        switch key {
        case .textSection(let chapter, let section):
            return chapter == 0
                ? .preface(paragraph: paragraph)
                : .text(chapter: chapter, section: section, paragraph: paragraph)

        case .lesson(let number):
            switch number {
            case 0: return .partIntroduction(part: 1, paragraph: paragraph)
            case 500: return .partIntroduction(part: 2, paragraph: paragraph)
            case 1...365: return .lesson(number: number, paragraph: paragraph)
            default: return nil
            }

        case .segment, .manual, .minuteDate:
            return nil
        }
    }

    /// The address of the paragraph a `Character` offset falls in.
    ///
    /// A segment is different from the rest. Its citation was located at export
    /// by matching its opening words, and refining it by offset would mean
    /// assuming the passage runs contiguously through the Text — which is not
    /// always true, because page furniture is sometimes removed mid-passage. So
    /// a segment cites where it begins, whatever the offset.
    static func citation(
        for key: ReadingKey,
        characterOffset: Int,
        corpus: CorpusService = .shared
    ) -> Citation? {
        if case .segment(let id) = key {
            return corpus.segment(id: id)?.parsedCitation
        }
        guard let display = displayString(for: key, corpus: corpus) else { return nil }
        return citation(for: key, characterOffset: characterOffset, displayString: display)
    }
}
