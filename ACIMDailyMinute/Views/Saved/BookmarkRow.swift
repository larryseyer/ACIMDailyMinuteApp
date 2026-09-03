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
        } else {
            rowContent
        }
    }

    /// Where tapping this row goes. A lesson opens that lesson, a Text section
    /// opens that section, a Manual passage opens that passage, and a minute
    /// opens the archive entry for the day it ran. `nil` when the underlying
    /// reading is no longer in the store — the row still renders, it just has
    /// nowhere to go, which is honest about what it can offer.
    private var destination: SavedDestination? {
        if parsedChannel == "lesson" {
            // No store check: `LessonDetailView` renders from `WorkbookCatalog`
            // for any valid number, so a lesson bookmark always has somewhere
            // to go even when its text has not been fetched on this device.
            guard let n = Int(parsedToken) else { return nil }
            if n == 0 || n == 500 { return .introduction(n) }
            guard (1...365).contains(n) else { return nil }
            return .lesson(n)
        }

        if parsedChannel == "minute" {
            if let m = minutes.first, !m.date.isEmpty { return .archiveDate(m.date) }
            if let r = archiveMinutes.first, !r.dateString.isEmpty { return .archiveDate(r.dateString) }
            return nil
        }

        if parsedChannel == "text" {
            guard let address = textAddress, textSection != nil else { return nil }
            return .textSection(chapter: address.chapter, section: address.section)
        }

        if parsedChannel == "manual" {
            guard let id = Int(parsedToken), CorpusService.shared.manualSegment(id: id) != nil else { return nil }
            return .manual(id)
        }

        return nil
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rowIcon)
                .foregroundStyle(Color.acimGold)
                .font(.title3)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(headerLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(bookmark.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let text = resolvedText {
                    Text(text)
                        .font(.acimBody)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                } else {
                    Text("Reading no longer available")
                        .font(.acimBody)
                        .foregroundStyle(.secondary)
                        .italic()
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var rowIcon: String {
        switch parsedChannel {
        case "lesson": "book.closed.fill"
        case "text", "manual": "text.book.closed"
        default: "sun.max.fill"
        }
    }

    private var headerLabel: String {
        if parsedChannel == "lesson" {
            guard let n = Int(parsedToken) else { return "Lesson" }
            if n == 0 || n == 500 { return "Introduction" }
            return "Lesson \(n)"
        }
        if parsedChannel == "text" {
            guard let address = textAddress else { return "Text" }
            return address.chapter == 0 ? "Preface" : "Chapter \(address.chapter)"
        }
        if parsedChannel == "manual" {
            return "Manual for Teachers"
        }
        return "Daily Minute"
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
            // The Manual has no titles, so unlike a Text section, which shows
            // its section title, this shows a preview of the passage itself.
            guard let id = Int(parsedToken), let segment = CorpusService.shared.manualSegment(id: id)
            else { return nil }
            return preview(segment.body)
        }

        if parsedChannel == "lesson" {
            if let n = Int(parsedToken), let intro = WorkbookBodiesCatalog.introduction(for: n) {
                return intro.title
            }
            if let l = lessons.first {
                return l.lessonTitle.isEmpty ? "Lesson \(l.lessonNumber)" : l.lessonTitle
            }
            if let r = archiveLessons.first {
                return r.text.isEmpty ? "Lesson \(r.lessonNumber ?? 0)" : r.text
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
