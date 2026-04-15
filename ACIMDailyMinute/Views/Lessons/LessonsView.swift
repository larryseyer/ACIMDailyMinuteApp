import SwiftUI
import SwiftData

/// Workbook-browser root. Renders a synthetic 1…365 spine and overlays whatever
/// local metadata we have from two `@Query` result sets.
///
/// Data sources (local only — no network in Phase 3.5):
///   * `DailyLesson` — authoritative: full text + title + date for lessons
///     previously surfaced as "today's" lesson.
///   * `ArchivedReading` where `channel == "daily-lesson"` — lightweight: title
///     stored in `text`, date in `dateString` (see `ArchiveService.persistInlineLessons`).
///
/// `DailyLesson` wins on conflict (it's a superset). Rows without either source
/// render a dimmed "Not yet read" state.
///
/// Phase 3.5c wires two refinements on top of the 3.5a/3.5b spine:
///   * `.searchable` — integer queries match that lesson exactly; any non-digit
///     query falls back to a `localizedStandardContains` title match.
///   * Jump-to-N sheet — toolbar button opens `JumpToLessonSheet`, which
///     programmatically appends an `Int` to the shared `NavigationPath`.
struct LessonsView: View {
    @Query(sort: \DailyLesson.lessonNumber) private var lessons: [DailyLesson]
    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-lesson" },
        sort: \ArchivedReading.lessonNumber
    ) private var archivedLessons: [ArchivedReading]
    @Query private var bookmarks: [Bookmark]

    @State private var path = NavigationPath()
    @State private var searchText: String = ""
    @State private var isJumpSheetPresented: Bool = false

    var body: some View {
        NavigationStack(path: $path) {
            let meta = buildMetaIndex()
            let bookmarkedNumbers = bookmarkedLessonNumbers()

            FilteredLessonsList(
                searchText: searchText,
                meta: meta,
                bookmarkedNumbers: bookmarkedNumbers
            )
            .listStyle(.plain)
            .navigationTitle("Lessons")
            .searchable(text: $searchText, prompt: "Search lessons")
            .toolbar {
                ToolbarItem(placement: jumpPlacement) {
                    Button {
                        isJumpSheetPresented = true
                    } label: {
                        Label("Jump", systemImage: "arrow.right.to.line")
                    }
                    .accessibilityLabel("Jump to lesson number")
                }
            }
            .sheet(isPresented: $isJumpSheetPresented) {
                JumpToLessonSheet(path: $path)
            }
            .navigationDestination(for: Int.self) { lessonNumber in
                LessonDetailView(lessonNumber: lessonNumber)
            }
            .onReceive(NotificationCenter.default.publisher(for: .deepLinkLesson)) { note in
                guard let n = note.object as? Int, (1...365).contains(n) else { return }
                path.append(n)
            }
        }
    }

    private var jumpPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
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

// MARK: - Filtered list

/// Private subview that owns the filtered `ForEach(1...365)`.
///
/// Pulling this out of `LessonsView.body` keeps the parent's `@Query`
/// re-evaluation independent of `searchText` changes, and lets `List` diff
/// rows cleanly as the filter predicate tightens and loosens.
private struct FilteredLessonsList: View {
    let searchText: String
    let meta: [Int: LessonMeta]
    let bookmarkedNumbers: Set<Int>

    var body: some View {
        let visible = filteredLessonNumbers()
        List {
            if visible.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(visible, id: \.self) { n in
                    LessonRow(
                        lessonNumber: n,
                        meta: meta[n],
                        isBookmarked: bookmarkedNumbers.contains(n)
                    )
                }
            }
        }
    }

    /// Filter contract (locked for Phase 3.5c):
    ///   * Empty / whitespace-only query → full spine 1…365.
    ///   * Trimmed query parses as `Int` → exact-match that single lesson iff in 1…365.
    ///   * Otherwise → title substring match via `localizedStandardContains` on
    ///     the merged `LessonMeta.title` (case + diacritic insensitive).
    private func filteredLessonNumbers() -> [Int] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(1...365)
        }

        if let n = Int(trimmed) {
            return (1...365).contains(n) ? [n] : []
        }

        return (1...365).filter { n in
            guard let title = meta[n]?.title, !title.isEmpty else { return false }
            return title.localizedStandardContains(trimmed)
        }
    }
}

#Preview {
    LessonsView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [DailyLesson.self, ArchivedReading.self, Bookmark.self], inMemory: true)
}
