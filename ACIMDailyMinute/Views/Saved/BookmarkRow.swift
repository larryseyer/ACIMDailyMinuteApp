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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: parsedChannel == "lesson" ? "book.closed.fill" : "sun.max.fill")
                .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.22))
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

    private var headerLabel: String {
        if parsedChannel == "lesson" {
            if let n = Int(parsedToken) { return "Lesson \(n)" }
            return "Lesson"
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

        if parsedChannel == "lesson" {
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
