import SwiftUI
import SwiftData

/// Workbook-browser root. Renders a synthetic 1…365 spine and overlays whatever
/// local metadata we have from two `@Query` result sets.
///
/// Data sources (local only — no network in Phase 3.5a):
///   * `DailyLesson` — authoritative: full text + title + date for lessons
///     previously surfaced as "today's" lesson.
///   * `ArchivedReading` where `channel == "daily-lesson"` — lightweight: title
///     stored in `text`, date in `dateString` (see `ArchiveService.persistInlineLessons`).
///
/// `DailyLesson` wins on conflict (it's a superset). Rows without either source
/// render a dimmed "Not yet read" state.
///
/// Navigation, search, and Jump-to-N affordances arrive in Phases 3.5b / 3.5c.
struct LessonsView: View {
    @Query(sort: \DailyLesson.lessonNumber) private var lessons: [DailyLesson]
    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-lesson" },
        sort: \ArchivedReading.lessonNumber
    ) private var archivedLessons: [ArchivedReading]
    @Query private var bookmarks: [Bookmark]

    var body: some View {
        NavigationStack {
            let meta = buildMetaIndex()
            let bookmarkedNumbers = bookmarkedLessonNumbers()

            List {
                ForEach(1...365, id: \.self) { n in
                    LessonRow(
                        lessonNumber: n,
                        meta: meta[n],
                        isBookmarked: bookmarkedNumbers.contains(n)
                    )
                }
            }
            .listStyle(.plain)
            .navigationTitle("Lessons")
        }
    }

    /// Merge `archivedLessons` first (weak signal), then `lessons` (strong signal),
    /// so DailyLesson overwrites any archive overlap with full-text authoritative data.
    private func buildMetaIndex() -> [Int: LessonMeta] {
        var index: [Int: LessonMeta] = [:]

        for archive in archivedLessons {
            guard let n = archive.lessonNumber else { continue }
            index[n] = LessonMeta(
                lessonNumber: n,
                title: archive.text.isEmpty ? nil : archive.text,
                dateRead: archive.dateString.isEmpty ? nil : archive.dateString,
                hasFullText: false
            )
        }

        for lesson in lessons {
            index[lesson.lessonNumber] = LessonMeta(
                lessonNumber: lesson.lessonNumber,
                title: lesson.lessonTitle.isEmpty ? nil : lesson.lessonTitle,
                dateRead: lesson.date.isEmpty ? nil : lesson.date,
                hasFullText: !lesson.text.isEmpty
            )
        }

        return index
    }

    private func bookmarkedLessonNumbers() -> Set<Int> {
        var result: Set<Int> = []
        for bookmark in bookmarks where bookmark.itemKey.hasPrefix("lesson:") {
            let suffix = bookmark.itemKey.dropFirst("lesson:".count)
            if let n = Int(suffix) { result.insert(n) }
        }
        return result
    }
}

#Preview {
    LessonsView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [DailyLesson.self, ArchivedReading.self, Bookmark.self], inMemory: true)
}
