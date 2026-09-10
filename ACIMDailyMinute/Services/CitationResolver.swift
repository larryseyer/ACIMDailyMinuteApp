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
    /// Nil where the reading has no addressable form: an archived minute
    /// whose segment is not yet known, and a Manual *cut* that has not been
    /// located (the structured question has a stem).
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
            if let intro = WorkbookBodiesCatalog.introduction(for: number) {
                return intro.citationStem
            }
            guard (1...365).contains(number),
                  WorkbookBodiesCatalog.body(for: number) != nil
            else { return nil }
            return "W-\(number)"
        case .segment(let id):
            return corpus.segment(id: id)?.parsedCitation?.stem
        case .manual(let id):
            return corpus.segment(id: id)?.parsedCitation?.stem
        case .manualSection(let number):
            guard let section = corpus.manualSection(number) else { return nil }
            return section.stem
        case .minuteDate:
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
            let body = WorkbookBodiesCatalog.introduction(for: number)?.body
                ?? ((1...365).contains(number) ? WorkbookBodiesCatalog.body(for: number) : nil)
            guard let body else { return nil }
            return ReadingText.displayString(from: body)

        case .manualSection(let number):
            guard let section = corpus.manualSection(number) else { return nil }
            return ReadingText.displayString(from: section.body)

        case .segment, .manual, .minuteDate:
            // A segment cites where it begins and never counts paragraphs; a
            // date key has no addressable form at all.
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
            if let intro = WorkbookBodiesCatalog.introduction(for: number) {
                return Citation(rawValue: "\(intro.citationStem).\(paragraph)")
            }
            guard (1...365).contains(number) else { return nil }
            return .lesson(number: number, paragraph: paragraph)

        case .manualSection(let number):
            return .manual(number: number, paragraph: paragraph)

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
    /// Where a tap on a printed citation goes: the reading it names, opened on
    /// the paragraph it names, painted and scrolled into view.
    ///
    /// Nil when the bundle does not hold the section, lesson or paragraph, so
    /// a citation that names nothing is printed and not tappable rather than
    /// opening the wrong place. The Preface is the one address that cannot
    /// name a paragraph — its two sections share one `Pref.N` numbering — so
    /// it opens at its head with nothing painted. Nothing is guessed.
    static func destination(
        for citation: Citation,
        corpus: CorpusService = .shared
    ) -> ReadingDestination? {
        switch citation {
        case .text(let chapter, let section, let paragraph):
            let key = ReadingKey.textSection(chapter: chapter, section: section)
            guard let spotlight = paragraphSpotlight(paragraph, of: key, corpus: corpus) else { return nil }
            return .textSection(TextSectionRef(chapter: chapter, section: section, spotlight: spotlight))

        case .preface:
            guard corpus.textSection(chapter: 0, section: 1) != nil else { return nil }
            return .textSection(TextSectionRef(chapter: 0, section: 1))

        case .lesson(let number, let paragraph):
            guard let spotlight = paragraphSpotlight(paragraph, of: .lesson(number), corpus: corpus) else { return nil }
            return .lesson(LessonRef(lessonNumber: number, spotlight: spotlight, presentsVideo: false))

        case .partIntroduction, .reviewIntroduction, .whatIsIntroduction:
            guard let intro = WorkbookBodiesCatalog.introduction(withStem: citation.stem) else { return nil }
            guard let spotlight = paragraphSpotlight(
                citation.paragraph, of: .lesson(intro.lessonNumber), corpus: corpus
            ) else { return nil }
            return .introduction(IntroductionRef(lessonNumber: intro.lessonNumber, spotlight: spotlight))

        case .manual(let number, let paragraph):
            guard let spotlight = paragraphSpotlight(
                paragraph, of: .manualSection(number), corpus: corpus
            ) else { return nil }
            return .manualSection(ManualSectionRef(number: number, spotlight: spotlight))
        }
    }

    /// A whole paragraph as a spotlight: its offsets in the bundled display
    /// string and its own text as the quote, so the screen finds it again in
    /// whatever string it draws — a published lesson draws the feed's.
    private static func paragraphSpotlight(
        _ paragraph: Int,
        of key: ReadingKey,
        corpus: CorpusService
    ) -> ReadingSpotlight? {
        guard let display = displayString(for: key, corpus: corpus),
              let range = Citation.paragraphRange(paragraph, in: display),
              !range.isEmpty
        else { return nil }
        let start = display.index(display.startIndex, offsetBy: range.lowerBound)
        let end = display.index(start, offsetBy: range.count)
        return ReadingSpotlight(
            startOffset: range.lowerBound,
            length: range.count,
            quote: String(display[start..<end])
        )
    }
}
