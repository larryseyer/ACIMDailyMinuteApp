import Foundation

/// How a `ReadingKey` names itself to a person.
///
/// Split from `ReadingKey.swift` so that file imports Foundation and nothing
/// else: naming a reading needs the corpus, the Workbook catalogues and the
/// citation resolver, and a key that carried those could not be compiled alone
/// by `tools/verify_reading_position.sh`. The address rule and the naming rule
/// are different jobs anyway — one says where a reading sits, the other says
/// what to call it.
extension ReadingKey {
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
