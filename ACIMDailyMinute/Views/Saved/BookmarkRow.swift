import SwiftUI
import SwiftData

struct BookmarkRow: View {
    let bookmark: Bookmark

    @Query private var minutes: [DailyMinute]
    @Query private var archiveMinutes: [ArchivedReading]
    @Query private var lessons: [DailyLesson]
    @Query private var archiveLessons: [ArchivedReading]

    private let parsedChannel: String
    private let parsedToken: String

    init(bookmark: Bookmark) {
        self.bookmark = bookmark

        let key = bookmark.itemKey
        if let sep = key.firstIndex(of: ":") {
            self.parsedChannel = String(key[..<sep])
            self.parsedToken = String(key[key.index(after: sep)...])
        } else {
            self.parsedChannel = ""
            self.parsedToken = ""
        }

        let token = self.parsedToken
        let lessonN = Int(self.parsedToken) ?? -1

        _minutes = Query(
            filter: #Predicate<DailyMinute> { m in
                m.segmentHash == token
            }
        )

        _archiveMinutes = Query(
            filter: #Predicate<ArchivedReading> { r in
                r.channel == "daily-minute" && r.lineHash == token
            }
        )

        _lessons = Query(
            filter: #Predicate<DailyLesson> { l in
                l.lessonNumber == lessonN
            }
        )

        _archiveLessons = Query(
            filter: #Predicate<ArchivedReading> { r in
                r.channel == "daily-lesson" && r.lessonNumber == lessonN
            }
        )
    }

    /// `"text:<chapter>.<section>"` split back into its two numbers.
    private var textAddress: (chapter: Int, section: Int)? {
        guard parsedChannel == "text" else { return nil }
        let parts = parsedToken.split(separator: ".").map(String.init)
        guard parts.count == 2, let chapter = Int(parts[0]), let section = Int(parts[1])
        else { return nil }
        return (chapter, section)
    }

    private var textSection: CorpusTextSection? {
        guard let address = textAddress else { return nil }
        return CorpusService.shared.textSection(chapter: address.chapter, section: address.section)
    }

    var body: some View {
        if let destination {
            NavigationLink(value: destination) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    /// Where tapping this row goes. A lesson opens that lesson, a Text section
    /// opens that section, and a Manual passage opens that passage. `nil` when
    /// the underlying reading is no longer in the store — the row still renders,
    /// it just has nowhere to go, which is honest about what it can offer.
    ///
    /// ⛔ A minute opens **its own words** wherever the row names a segment, and
    /// only falls back to the archive day when it does not. A minute saved from
    /// the Today card names a segment and its day is not in the archive yet —
    /// today has not been archived — so the day route opened an archive screen
    /// with nothing on it. An `ArchivedReading` carries no segment id, and its
    /// day is in the archive by construction, so a row saved there keeps the
    /// day. A bookmark carries no passage, so no row here opens on a spotlight.
    private var destination: SavedDestination? {
        if parsedChannel == "lesson" {
            // No store check: `LessonDetailView` renders from `WorkbookCatalog`
            // for any valid number, so a lesson bookmark always has somewhere
            // to go even when its text has not been fetched on this device.
            guard let n = Int(parsedToken) else { return nil }
            if WorkbookBodiesCatalog.isIntroduction(n) {
                return .introduction(IntroductionRef(lessonNumber: n))
            }
            guard (1...365).contains(n) else { return nil }
            return .lesson(LessonRef(lessonNumber: n, presentsVideo: false))
        }

        if parsedChannel == "minute" {
            if let m = minutes.first, m.segmentId > 0,
               CorpusService.shared.segment(id: m.segmentId) != nil {
                return .segment(SegmentReadingRef(segmentId: m.segmentId))
            }
            if let m = minutes.first, !m.date.isEmpty { return .archiveDate(m.date) }
            if let r = archiveMinutes.first, !r.dateString.isEmpty { return .archiveDate(r.dateString) }
            return nil
        }

        if parsedChannel == "text" {
            guard let address = textAddress, textSection != nil else { return nil }
            return .textSection(TextSectionRef(chapter: address.chapter, section: address.section))
        }

        if parsedChannel == "manual" {
            guard let id = Int(parsedToken), CorpusService.shared.manualSegment(id: id) != nil else { return nil }
            return .manual(ManualSegmentRef(segmentId: id))
        }

        if parsedChannel == "manual-q" {
            guard let n = Int(parsedToken), CorpusService.shared.manualSection(n) != nil else { return nil }
            return .manualSection(ManualSectionRef(number: n))
        }

        return nil
    }

    private var rowContent: some View {
        SavedMarkChrome(
            quote: resolvedText ?? "Reading no longer available",
            citationRaw: citationRaw,
            dateText: SavedMarkCopy.dateText(kind: "Saved", at: bookmark.createdAt)
        )
    }

    /// `Bookmark.itemKey` is not a `ReadingKey`. Map the channels this row
    /// already understands onto one so the stem can be looked up, and nowhere
    /// else.
    private var readingKey: ReadingKey? {
        switch parsedChannel {
        case "lesson":
            guard let n = Int(parsedToken) else { return nil }
            return .lesson(n)
        case "text":
            guard let address = textAddress else { return nil }
            return .textSection(chapter: address.chapter, section: address.section)
        case "manual":
            guard let id = Int(parsedToken) else { return nil }
            return .manual(id)
        case "manual-q":
            guard let n = Int(parsedToken) else { return nil }
            return .manualSection(n)
        case "minute":
            if let m = minutes.first, m.segmentId > 0 {
                return .segment(m.segmentId)
            }
            if let m = minutes.first, !m.date.isEmpty {
                return .minuteDate(m.date)
            }
            if let r = archiveMinutes.first, !r.dateString.isEmpty {
                return .minuteDate(r.dateString)
            }
            return nil
        default:
            return nil
        }
    }

    private var citationRaw: String? {
        guard let readingKey else { return nil }
        return SavedCitation.stem(for: readingKey)
    }

    private var resolvedText: String? {
        guard !parsedChannel.isEmpty, !parsedToken.isEmpty else { return nil }

        if parsedChannel == "minute" {
            if let m = minutes.first { return preview(m.text) }
            if let r = archiveMinutes.first { return preview(r.text) }
            return nil
        }

        if parsedChannel == "text" {
            return textSection?.sectionTitle
        }

        if parsedChannel == "manual" {
            guard let id = Int(parsedToken), let segment = CorpusService.shared.manualSegment(id: id)
            else { return nil }
            return preview(segment.body)
        }

        if parsedChannel == "manual-q" {
            guard let n = Int(parsedToken) else { return nil }
            return CorpusService.shared.manualSection(n)?.title
        }

        if parsedChannel == "lesson" {
            if let n = Int(parsedToken), let intro = WorkbookBodiesCatalog.introduction(for: n) {
                return intro.title
            }
            if let l = lessons.first {
                return l.lessonTitle.isEmpty ? "Lesson \(l.lessonNumber)" : l.lessonTitle
            }
            if let r = archiveLessons.first {
                if let n = r.lessonNumber, n > 0 {
                    return r.text.isEmpty ? "Lesson \(n)" : r.text
                }
                return r.text.isEmpty ? nil : r.text
            }
            return nil
        }

        return nil
    }

    private func preview(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: "\n", with: " ")
        if collapsed.count <= 140 { return collapsed }
        let idx = collapsed.index(collapsed.startIndex, offsetBy: 140)
        return String(collapsed[..<idx]) + "…"
    }
}
