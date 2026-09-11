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
///     it until the sheet has dismissed, then pushes the lesson. Opening
///     the player from inside that sheet nested two presentations and
///     crashed (ACIMDailyMinuteTV-2026-09-09-105807.ips).
struct LessonsView: View {
    @Environment(AudioManager.self) private var audio
    @Query(sort: \DailyLesson.lessonNumber) private var lessons: [DailyLesson]
    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-lesson" },
        sort: \ArchivedReading.lessonNumber
    ) private var archivedLessons: [ArchivedReading]
    @Query private var bookmarks: [Bookmark]

    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-minute" },
        sort: \ArchivedReading.dateString
    ) private var archivedMinutes: [ArchivedReading]
    @Query private var storedMinutes: [DailyMinute]
    @Query(
        filter: #Predicate<CachedPodcastEpisode> { $0.channel == "minute" },
        sort: \CachedPodcastEpisode.publishedAt,
        order: .reverse
    )
    private var cachedMinutes: [CachedPodcastEpisode]

    @State private var path = NavigationPath()
    @State private var searchText: String = ""
    @State private var isJumpSheetPresented: Bool = false
    #if os(tvOS)
    @State private var pendingJump: Int?
    #endif
    @State private var shelf: CourseShelf = .lesson
    @State private var minuteCalendar = ArchiveCalendarState.starting(now: Date())
    /// Bound so the spine redraws when a lesson is marked done on its screen.
    @AppStorage(WorkbookCompletion.defaultsKey) private var completedLessonsData: Data = Data()

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Shelf", selection: $shelf) {
                    ForEach(CourseShelf.allCases) { Text($0.rawValue).tag($0) }
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
                if trimmedQuery.isEmpty, shelf == .minute, let item = minuteResume {
                    ListenResumeRibbon(
                        item: item,
                        isActive: audio.isActive(url: item.audioURL)
                            || (!item.episodeID.isEmpty && audio.currentEpisodeID == item.episodeID),
                        isPlaying: audio.isPlaying,
                        onTap: {
                            play(url: item.audioURL, title: item.title, episodeID: item.episodeID)
                        }
                    )
                    .padding(.horizontal, 20)
                }

                if trimmedQuery.isEmpty, let book = ribbonBook {
                    ContinueReadingRow(book: book)
                        .padding(.horizontal, 20)
                }

                Group {
                    if trimmedQuery.isEmpty {
                        switch shelf {
                        case .minute: minuteShelf
                        case .lesson: workbookShelf
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
                LessonDetailView(lessonNumber: lessonNumber, presentsVideo: false)
            }
            .navigationDestination(for: MinuteDateRef.self) { ref in
                MinuteReadingView(
                    dateString: ref.dateString,
                    availability: minuteAvailability(of: ref.dateString),
                    archived: minuteDates
                )
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
                shelf = .lesson
                path.append(n)
            }
        }
    }

    private var ribbonBook: ReadingPosition.Book? {
        switch shelf {
        case .minute: nil
        case .lesson: .workbook
        case .text: .text
        case .manual: .manual
        }
    }

    private var minuteDates: Set<String> {
        var dates = Set(archivedMinutes.map(\.dateString).filter { !$0.isEmpty })
        for minute in storedMinutes where !minute.date.isEmpty {
            dates.insert(minute.date)
        }
        return dates
    }

    private func minuteAvailability(of dateString: String) -> MinuteSchedule.Availability {
        guard let day = LessonSchedule.day(from: dateString) else { return .unknown }
        return MinuteSchedule.availability(of: day, archived: minuteDates, today: ArchiveView.today())
    }

    private var minuteResume: ListenLibrary.Resume? {
        ListenLibrary.resume(
            hasActiveAudio: audio.hasActiveAudio,
            nowPlayingTitle: audio.currentTitle,
            nowPlayingURL: audio.currentURL,
            nowPlayingEpisodeID: audio.currentEpisodeID,
            inProgress: []
        )
    }

    private func selectedMinuteRow(_ row: ListenLibrary.Row) -> some View {
        let dateString = ArchiveView.dateString(from: minuteCalendar.selection)
        let sentence = minuteAvailability(of: dateString).sentence

        return HStack(alignment: .center, spacing: 8) {
            ListenPlayableRow(
                row: row,
                isActive: isMinuteActive(row),
                isPlaying: audio.isPlaying,
                unrecordedCaption: ListenLibrary.showsPlay(audioURL: row.audioURL)
                    ? nil
                    : (sentence ?? ListenLibrary.unrecordedCaption(availableOnFormatted: nil)),
                onTap: { play(url: row.audioURL, title: row.title, episodeID: row.episodeID) }
            )
            Button {
                path.append(MinuteDateRef(dateString: dateString))
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open reading")
        }
        .padding(14)
        .background(Color.acimCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var minuteShelf: some View {
        let row = minuteRow(for: ArchiveView.dateString(from: minuteCalendar.selection))
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                selectedMinuteRow(row)

                ArchiveCalendarView(
                    selection: $minuteCalendar.selection,
                    visibleMonth: $minuteCalendar.visibleMonth,
                    availableDateStrings: minuteDates
                )
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .readableContentWidth()
        }
        .toolbar {
            ToolbarItem(placement: jumpPlacement) {
                Button("Today") {
                    withAnimation {
                        minuteCalendar.revealToday(now: Date(), availableDateStrings: minuteDates)
                    }
                }
            }
        }
    }

    private func minuteRow(for dateString: String) -> ListenLibrary.Row {
        let daily = storedMinutes.first { $0.date == dateString }?.audioURL
        let archived = archivedMinutes.first { $0.dateString == dateString }?.audioURL
        let podcast = cachedMinutes.first {
            ArchiveView.dateString(from: $0.publishedAt) == dateString
        }
        let audioURL = ListenLibrary.minuteAudio(
            daily: daily,
            archived: archived,
            podcast: podcast?.audioURL
        )
        return ListenLibrary.Row(
            id: "minute:\(dateString)",
            title: ArchiveView.longDateString(from: minuteCalendar.selection),
            audioURL: audioURL,
            episodeID: podcast?.id ?? dateString
        )
    }

    private func play(url: String, title: String, episodeID: String) {
        guard ListenLibrary.showsPlay(audioURL: url) else { return }
        audio.playOrToggle(url: url, title: title, episodeID: episodeID)
    }

    private func isMinuteActive(_ row: ListenLibrary.Row) -> Bool {
        if ListenLibrary.showsPlay(audioURL: row.audioURL), audio.isActive(url: row.audioURL) {
            return true
        }
        guard audio.hasActiveAudio, !audio.currentEpisodeID.isEmpty else { return false }
        return audio.currentEpisodeID == row.episodeID
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

    /// tvOS must not push while Jump to Lesson is still up. The sheet used
    /// to present the player on top of itself and crash; waiting for
    /// dismiss keeps that door closed even though the destination is now
    /// the reading.
    private func openPendingJump() {
        #if os(tvOS)
        guard let n = pendingJump else { return }
        pendingJump = nil
        path.append(n)
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

            NavigationLink(value: IntroductionRef(lessonNumber: lessonNumber)) { label }
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
        .modelContainer(for: [DailyLesson.self, DailyMinute.self, ArchivedReading.self, Bookmark.self, CachedPodcastEpisode.self], inMemory: true)
}
