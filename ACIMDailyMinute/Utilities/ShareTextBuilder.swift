import Foundation

enum ShareTextBuilder {
    /// How a shared passage names its source.
    ///
    /// Replaces the pipeline's `source_reference`, which is the source PDF's own
    /// name (`github_push.py:402` writes `source_pdf` straight through) and
    /// shows a reader `Text Part A`. The lookup is against the bundle, never the
    /// feed, so a shared passage carries its address offline and after every
    /// network service here has ended.
    static func attribution(segmentId: Int, corpus: CorpusService = .shared) -> String {
        guard let segment = corpus.segment(id: segmentId) else {
            return "A Course in Miracles"
        }
        return "A Course in Miracles, \(segment.citation ?? segment.bookName)"
    }

    static func minuteShareText(_ minute: DailyMinute) -> String {
        var parts: [String] = [minute.text]
        parts.append("— \(attribution(segmentId: minute.segmentId))")
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }

    static func lessonShareText(_ lesson: DailyLesson) -> String {
        let header = "Lesson \(lesson.lessonNumber): \(lesson.lessonTitle)"
        var parts: [String] = [header, lesson.text]
        parts.append("— A Course in Miracles, Workbook for Students")
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }

    /// Matches `lessonShareText`'s shape so a shared passage looks the same
    /// whichever part of the book it came from.
    static func textSectionShareText(_ section: CorpusTextSection) -> String {
        let chapter = section.chapterNumber == 0
            ? section.chapterTitle
            : "Chapter \(section.chapterNumber)"
        var parts: [String] = ["\(chapter): \(section.sectionTitle)", section.body]
        let stem = CitationResolver.stem(
            for: .textSection(chapter: section.chapterNumber, section: section.sectionNumber)
        )
        parts.append(stem.map { "— A Course in Miracles, Text, \($0)" }
                     ?? "— A Course in Miracles, Text")
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }

    /// How an archived passage names its source.
    ///
    /// ⛔ An archived row has NO segment id — the feed's inline archive entries
    /// carry neither `segment_id` nor `youtube_id` (`DataService.swift:204`), so
    /// there is nothing to resolve a citation with. It names its book instead.
    /// Matching the passage by its text at runtime is not the alternative: the
    /// locator belongs at export, and keying a row by a hash of its content is
    /// the bug this project keeps rediscovering.
    static func attribution(sourceReference: String) -> String {
        let trimmed = sourceReference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "A Course in Miracles" }
        return "A Course in Miracles, \(CorpusSegment.bookName(forSourcePDF: trimmed))"
    }

    /// Matches `minuteShareText`'s format verbatim so the share sheet output
    /// looks identical regardless of whether a user shared from Today or Archive.
    static func archivedMinuteShareText(_ reading: ArchivedReading) -> String {
        var parts: [String] = [reading.text]
        parts.append("— \(attribution(sourceReference: reading.sourceReference))")
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }

    /// Archive lesson entries only carry a title (stored in `reading.text` per
    /// `ArchiveService.persistInlineLessons`), so this output is title-only —
    /// unlike `lessonShareText`, which includes the full body. The trailing
    /// attribution lines stay consistent with the Workbook framing.
    static func archivedLessonShareText(_ reading: ArchivedReading) -> String {
        let n = reading.lessonNumber ?? 0
        let title = reading.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let header = title.isEmpty ? "Lesson \(n)" : "Lesson \(n): \(title)"
        var parts: [String] = [header]
        parts.append("— A Course in Miracles, Workbook for Students")
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }
    /// A Part Introduction shares like a lesson, because that is what it is —
    /// a Workbook reading that was never published as a numbered day.
    static func introductionShareText(title: String, body: String) -> String {
        var parts: [String] = [title, body]
        parts.append("— A Course in Miracles, Workbook for Students")
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }

    /// ⛔ A Manual passage names its book and no address. The Manual ships as
    /// 105 word-count cuts with no titles and `citation: nil`, so there is
    /// nothing narrower to cite, and inventing one here would print an address
    /// into a reader's share sheet that nothing else in the app agrees with.
    static func manualShareText(body: String) -> String {
        var parts: [String] = [body]
        parts.append("— A Course in Miracles, Manual for Teachers")
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }
}
