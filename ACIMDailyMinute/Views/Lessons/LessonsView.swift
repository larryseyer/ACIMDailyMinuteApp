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
///   * `.searchable` — one field for the whole Course; see ReadSearchResultsList.
///   * Jump-to-N sheet — toolbar button opens `JumpToLessonSheet`, which
///     reports the number. iOS appends it to `NavigationPath`; tvOS holds
///     it until the sheet has dismissed, then opens the player.
struct LessonsView: View {
    @Environment(AudioManager.self) private var audio
    #if os(tvOS)
    @Environment(\.openPlayer) private var openPlayer
    #endif
    @Query(sort: \DailyLesson.lessonNumber) private var lessons: [DailyLesson]
    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-lesson" },
        sort: \ArchivedReading.lessonNumber
    ) private var archivedLessons: [ArchivedReading]
    @Query private var bookmarks: [Bookmark]

    /// The three books in one volume share a tab. A sixth tab would collapse
    /// into the iOS "More" list, which is the same reason the Saved tab
    /// carries three segments.
    private enum Shelf: String, CaseIterable, Identifiable {
        case workbook = "Workbook"
        case text = "Text"
        case manual = "Manual"

        var id: String { rawValue }
    }

    @State private var path = NavigationPath()
    @State private var searchText: String = ""
    @State private var isJumpSheetPresented: Bool = false
    #if os(tvOS)
    @State private var pendingJump: Int?
    #endif
    @State private var shelf: Shelf = .workbook
    /// Bound so the spine redraws when a lesson is marked done on its screen.
    @AppStorage(WorkbookCompletion.defaultsKey) private var completedLessonsData: Data = Data()

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Shelf", selection: $shelf) {
                    ForEach(Shelf.allCases) { Text($0.rawValue).tag($0) }
                }
                #if !os(tvOS)
                .pickerStyle(.segmented)
                #endif
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // ⛔ Above the list rather than inside it. The Workbook spine
                // scrolls itself to the lesson in play the moment it appears,
                // which carried a row at the top of that list straight off the
                // screen — a ribbon nobody can see is worse than none. Here it
                // belongs to the shelf, not to the scroll.
                //
                // Hidden while a query is typed: the results list replaces the
                // shelf, and where the reader stopped is not an answer to what
                // they are searching for.
                if trimmedQuery.isEmpty {
                    ContinueReadingRow(book: ribbonBook)
                        .padding(.horizontal, 20)
                }

                Group {
                    if trimmedQuery.isEmpty {
                        switch shelf {
                        case .workbook: workbookShelf
                        case .text: TextChaptersView()
                        case .manual: manualShelf
                        }
                    } else {
                        ReadSearchResultsList(query: trimmedQuery)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Read")
            #if !os(tvOS)
            // On tvOS `.searchable` is a permanent a-z keyboard, not a field
            // a viewer opens, and it covers the chapter list.
            .searchable(text: $searchText, prompt: "Search the Course")
            #endif
            .navigationDestination(for: Int.self) { lessonNumber in
                LessonDetailView(lessonNumber: lessonNumber)
            }
            .navigationDestination(for: TextChapterRef.self) { ref in
                TextChapterView(chapter: ref.chapter)
            }
            .navigationDestination(for: IntroductionRef.self) { ref in
                WorkbookIntroductionView(lessonNumber: ref.lessonNumber, spotlight: ref.spotlight)
            }
            .navigationDestination(for: LessonRef.self) { ref in
                LessonDetailView(lessonNumber: ref.lessonNumber, spotlight: ref.spotlight, presentsVideo: ref.presentsVideo)
            }
            .navigationDestination(for: ManualSegmentRef.self) { ref in
                ManualSegmentView(segmentId: ref.segmentId, spotlight: ref.spotlight)
            }
            .navigationDestination(for: ManualSectionRef.self) { ref in
                ManualSectionView(number: ref.number, spotlight: ref.spotlight)
            }
            .readingDestinations(path: $path)
            .onReceive(NotificationCenter.default.publisher(for: .deepLinkLesson)) { note in
                guard let n = note.object as? Int, (1...365).contains(n) else { return }
                // A widget or notification tap on a lesson must never land on a
                // chapter list.
                shelf = .workbook
                #if os(tvOS)
                openPlayer(.workbookLesson(n))
                #else
                path.append(n)
                #endif
            }
        }
    }

    private var ribbonBook: ReadingPosition.Book {
        switch shelf {
        case .workbook: .workbook
        case .text: .text
        case .manual: .manual
        }
    }

    private var manualShelf: some View {
        let corpus = CorpusService.shared
        return List {
            if corpus.manualSections.isEmpty {
                ContentUnavailableView {
                    Label("The Manual is unavailable", systemImage: "book.closed")
                } description: {
                    Text("The bundled Manual could not be read from this build.")
                }
                #if !os(tvOS)
                .listRowSeparator(.hidden)
                #endif
                .listRowBackground(Color.clear)
            } else {
                ForEach(corpus.manualSections) { section in
                    NavigationLink(value: ManualSectionRef(number: section.number)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.stem)
                                .font(.acimCaption2.monospaced())
                                .foregroundStyle(.secondary)
                            Text(section.title)
                                .font(.system(.subheadline, design: .serif).weight(.semibold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .listStyle(.plain)
        .readableContentWidth()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
        }
    }

    private var workbookShelf: some View {
        let meta = buildMetaIndex()
        let bookmarkedNumbers = bookmarkedLessonNumbers()
        let anchor = recordedAnchor()

        return FilteredLessonsList(
            meta: meta,
            bookmarkedNumbers: bookmarkedNumbers,
            completedNumbers: Set(WorkbookCompletion.entries.keys),
            latestLessonNumber: anchor.number,
            latestPublishedAt: anchor.date,
            onOpenText: { shelf = .text }
        )
        .listStyle(.plain)
        .readableContentWidth()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
        }
        .toolbar {
            ToolbarItem(placement: jumpPlacement) {
                Button {
                    isJumpSheetPresented = true
                } label: {
                    #if os(tvOS)
                    // Icon+title in this slot sizes to the glyph and clips to "J...p".
                    Text("Jump to Lesson")
                        .fixedSize(horizontal: true, vertical: false)
                    #else
                    Label("Jump", systemImage: "arrow.right.to.line")
                    #endif
                }
                #if os(tvOS)
                .buttonStyle(.bordered)
                #endif
                .accessibilityLabel("Jump to lesson number")
            }
        }
        .sheet(isPresented: $isJumpSheetPresented, onDismiss: openPendingJump) {
            JumpToLessonSheet { n in
                #if os(tvOS)
                pendingJump = n
                #else
                path.append(n)
                #endif
            }
        }
    }

    /// tvOS presents the player as a sheet. Opening it while Jump to Lesson
    /// is still up nests two sheets; the inner one has no AudioManager and
    /// TVPlayerView assertionFailure's (ACIMDailyMinuteTV-2026-09-09-105807.ips).
    private func openPendingJump() {
        #if os(tvOS)
        guard let n = pendingJump else { return }
        pendingJump = nil
        openPlayer(.workbookLesson(n))
        #endif
    }

    private var jumpPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #elseif os(tvOS)
        .automatic
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
        let anchor = LessonSchedule.anchor(
            from: lessons.map { ($0.lessonNumber, $0.publishedAt) }
                + archivedLessons.map { ($0.lessonNumber ?? 0, $0.timestamp) }
        )
        return (anchor?.number ?? 0, anchor?.date)
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

// MARK: - Lesson spine

/// Private subview that owns the `ForEach(1...365)`.
///
/// Pulling this out of `LessonsView.body` keeps the parent's `@Query`
/// re-evaluation independent of the rows' own state, and lets `List` diff
/// rows cleanly as the metadata behind them fills in.
private struct FilteredLessonsList: View {
    let meta: [Int: LessonMeta]
    let bookmarkedNumbers: Set<Int>
    let completedNumbers: Set<Int>
    let latestLessonNumber: Int
    let latestPublishedAt: Date?
    let onOpenText: () -> Void

    /// Opening the tab should land on the lesson in play, not on Lesson 1. Only
    /// fires once per appearance — re-running it on a later redraw would yank
    /// the list out from under someone who has scrolled away.
    @State private var hasScrolledToCurrent = false
    #if os(tvOS)
    @Environment(\.openPlayer) private var openPlayer
    #endif

    var body: some View {
        let visible = lessonNumbers()
        ScrollViewReader { proxy in
            List {
                if latestLessonNumber > 0 {
                    cadenceHeader
                        #if !os(tvOS)
                        .listRowSeparator(.hidden)
                        #endif
                        .listRowBackground(Color.clear)
                }
                ForEach(visible, id: \.self) { n in
                    ForEach(Self.introductions(before: n), id: \.lessonNumber) { intro in
                        introductionRow(intro.lessonNumber)
                    }
                    LessonRow(
                        lessonNumber: n,
                        meta: meta[n],
                        isBookmarked: bookmarkedNumbers.contains(n),
                        isCompleted: completedNumbers.contains(n),
                        availableOn: latestPublishedAt.flatMap {
                            LessonSchedule.availabilityDate(
                                for: n,
                                latestRecorded: latestLessonNumber,
                                latestDate: $0
                            )
                        }
                    )
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

    /// Introductions ride alongside the lesson they precede rather than being
    /// inserted into the 1...365 spine, so the list's rows stay plain integers
    /// and a lesson number is still its own row id. The title comes from the
    /// corpus rather than from a literal here, so the row and the reading can
    /// never disagree about its name.
    private static func introductions(before lessonNumber: Int) -> [WorkbookIntroduction] {
        WorkbookBodiesCatalog.allIntroductions.filter { $0.insertBefore == lessonNumber }
    }

    @ViewBuilder
    private func introductionRow(_ lessonNumber: Int) -> some View {
        if let intro = WorkbookBodiesCatalog.introduction(for: lessonNumber) {
            let label = VStack(alignment: .leading, spacing: 2) {
                Text(intro.title)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Workbook for Students")
                    .font(.acimCaption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())

            #if os(tvOS)
            Button { openPlayer(.workbookLesson(lessonNumber)) } label: { label }
            #else
            NavigationLink(value: IntroductionRef(lessonNumber: lessonNumber)) { label }
            #endif
        }
    }

    /// Scrolls the newest recorded lesson to the top. When today's lesson has
    /// not been produced yet (a weekend, or before the 02:00 run) the newest
    /// recorded one *is* the right target, so no separate "today" lookup exists.
    private func scrollToCurrentLesson(proxy: ScrollViewProxy, visible: [Int]) {
        guard !hasScrolledToCurrent,
              latestLessonNumber > 0,
              visible.contains(latestLessonNumber)
        else { return }

        hasScrolledToCurrent = true
        // The row has to exist before it can be scrolled to; on a cold open the
        // List is still being laid out when `onAppear` runs.
        DispatchQueue.main.async {
            proxy.scrollTo(latestLessonNumber, anchor: .top)
        }
    }

    /// `latestPublishedAt` deliberately does not appear here. It anchors the
    /// availability schedule, but when a lesson was published is the app's own
    /// bookkeeping and means nothing to the reader.
    private var cadenceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lesson \(latestLessonNumber) of 365")
            Button(action: onOpenText) {
                HStack(spacing: 4) {
                    Text("After Lesson 365, the Text begins.")
                    Image(systemName: "chevron.right")
                        .font(.acimCaption2)
                }
            }
            .buttonStyle(.plain)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    /// The whole spine. Searching the Workbook is the Read tab's one search,
    /// which replaces this list while a query is typed.
    private func lessonNumbers() -> [Int] { Array(1...365) }
}

#Preview {
    LessonsView()
        .preferredColorScheme(.dark)
        .modelContainer(for: [DailyLesson.self, ArchivedReading.self, Bookmark.self], inMemory: true)
}
