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
/// `DailyLesson` wins on conflict (it's a superset).
///
/// The spine runs to 365 but the publisher records one lesson per weekday, so
/// most of it is not out yet. `LessonSchedule` turns the latest recorded lesson
/// into a due date for every later number; those rows render dimmed and inert
/// with an "Available" date instead of tapping through to an empty screen.
///
/// Phase 3.5c wires two refinements on top of the 3.5a/3.5b spine:
///   * `.searchable` — integer queries match that lesson exactly; any non-digit
///     query falls back to a `localizedStandardContains` title match.
///   * Jump-to-N sheet — toolbar button opens `JumpToLessonSheet`, which
///     programmatically appends an `Int` to the shared `NavigationPath`.
struct LessonsView: View {
    @Environment(AudioManager.self) private var audio
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

            let anchor = recordedAnchor()

            FilteredLessonsList(
                searchText: searchText,
                meta: meta,
                bookmarkedNumbers: bookmarkedNumbers,
                latestLessonNumber: anchor.number,
                latestPublishedAt: anchor.date
            )
            .listStyle(.plain)
            .readableContentWidth()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
            }
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
                hasFullText: false
            )
        }

        for lesson in lessons {
            index[lesson.lessonNumber] = LessonMeta(
                lessonNumber: lesson.lessonNumber,
                title: lesson.lessonTitle.isEmpty ? nil : lesson.lessonTitle,
                hasFullText: !lesson.text.isEmpty
            )
        }

        return index
    }

    /// Highest lesson we have evidence was actually recorded, plus the date it
    /// was published — the anchor `LessonSchedule` counts weekdays from.
    ///
    /// A `DailyLesson` row is the strong signal and carries a parsed
    /// `publishedAt`. The archive can know about a *later* lesson than the
    /// Daily Lesson endpoint currently serves, so it is folded in too; its
    /// `timestamp` is optional, and an archive hit without one is ignored
    /// rather than anchoring the whole schedule on a guess.
    private func recordedAnchor() -> (number: Int, date: Date?) {
        var number = lessons.last?.lessonNumber ?? 0
        var date = lessons.last?.publishedAt

        for archive in archivedLessons {
            guard let n = archive.lessonNumber, n > number, let stamp = archive.timestamp else { continue }
            number = n
            date = stamp
        }

        return (number, date)
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
    let latestLessonNumber: Int
    let latestPublishedAt: Date?

    /// Opening the tab should land on the lesson in play, not on Lesson 1. Only
    /// fires once per appearance — re-running it after every filter change would
    /// yank the list out from under someone who has scrolled away or searched.
    @State private var hasScrolledToCurrent = false

    var body: some View {
        let visible = filteredLessonNumbers()
        ScrollViewReader { proxy in
            List {
                if latestLessonNumber > 0 {
                    cadenceHeader
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                if visible.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(visible, id: \.self) { n in
                        LessonRow(
                            lessonNumber: n,
                            meta: meta[n],
                            isBookmarked: bookmarkedNumbers.contains(n),
                            availableOn: LessonSchedule.availabilityDate(
                                for: n,
                                latestRecorded: latestLessonNumber,
                                latestDate: latestPublishedAt ?? Date()
                            )
                        )
                    }
                }
            }
            .onAppear { scrollToCurrentLesson(proxy: proxy, visible: visible) }
            .onChange(of: latestLessonNumber) { _, _ in
                // The anchor arrives asynchronously — the first fetch can land
                // after the list has already drawn, and until it does there is
                // no current lesson to scroll to.
                scrollToCurrentLesson(proxy: proxy, visible: visible)
            }
        }
    }

    /// Scrolls the newest recorded lesson to the top. When today's lesson has
    /// not been produced yet (a weekend, or before the 02:00 run) the newest
    /// recorded one *is* the right target, so no separate "today" lookup exists.
    private func scrollToCurrentLesson(proxy: ScrollViewProxy, visible: [Int]) {
        guard !hasScrolledToCurrent,
              latestLessonNumber > 0,
              searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              visible.contains(latestLessonNumber)
        else { return }

        hasScrolledToCurrent = true
        // The row has to exist before it can be scrolled to; on a cold open the
        // List is still being laid out when `onAppear` runs.
        DispatchQueue.main.async {
            proxy.scrollTo(latestLessonNumber, anchor: .top)
        }
    }

    private var cadenceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lesson \(latestLessonNumber) of 365")
            if let date = latestPublishedAt {
                Text("Published \(date, format: .relative(presentation: .named))")
            }
            Text("After Lesson 365, the Text begins.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
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
