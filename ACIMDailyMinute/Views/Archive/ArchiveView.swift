import SwiftUI
import SwiftData

/// Root of the Video tab: the Course in picture.
///
/// Four shelves (`CourseShelf`), default Lesson. A row starts the picture:
/// YouTube when a recording exists (iPhone, iPad, Mac), the composed player
/// otherwise. Apple TV always composes. The calendar is the Minute shelf,
/// not the tab.
///
/// Search (Minute only) filters `ArchivedReading.searchableText`. Pull-to-refresh
/// re-fetches daily JSON and both podcast feeds so lesson YouTube ids exist
/// without opening Listen first.
struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ConnectivityManager.self) private var connectivity
    @Environment(AudioManager.self) private var audio
    @Environment(\.openPlayer) private var openPlayer

    @Query(sort: \ArchivedReading.dateString, order: .reverse)
    private var allReadings: [ArchivedReading]
    @Query(sort: \DailyLesson.lessonNumber) private var lessons: [DailyLesson]
    @Query private var minutes: [DailyMinute]
    @Query private var podcasts: [CachedPodcastEpisode]

    @State private var path = NavigationPath()
    @State private var searchText: String = ""
    @State private var archiveCalendar = ArchiveCalendarState.starting(now: Date())
    @State private var isRefreshing = false
    @State private var shelf: CourseShelf = .lesson
    @State private var isJumpSheetPresented = false
    @State private var pendingJump: Int?
    #if os(iOS) || os(macOS)
    @State private var youtubeClip: VideoYouTubeClip?
    #endif

    var body: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
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

                Group {
                    if shelf == .minute, !trimmed.isEmpty {
                        ArchiveSearchResultsList(query: trimmed, readings: allReadings, path: $path)
                    } else {
                        switch shelf {
                        case .minute: minuteShelf
                        case .lesson: lessonShelf
                        case .text: textShelf
                        case .manual: manualShelf
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // ⛔ The mini player floats over this screen, so the last row
            // owes it room. Thirteen surfaces reserved it and this one did
            // not, which covered the bottom entry whenever audio was playing.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
            }
            .navigationTitle("Video")
            #if !os(tvOS)
            // Same as the Read tab: on tvOS `.searchable` takes over the
            // screen rather than waiting to be opened. Query is ignored on
            // Lesson / Text / Manual.
            .searchable(text: $searchText, prompt: "Search past readings")
            .refreshable {
                if connectivity.isConnected {
                    await refresh()
                }
            }
            .task {
                await refreshPodcasts(force: false)
            }
            #endif
            .navigationDestination(for: String.self) { dateString in
                ArchiveDateDetailView(
                    dateString: dateString,
                    availability: availability(of: dateString),
                    archived: datesWithReadings
                )
            }
            .navigationDestination(for: VideoTextChapterRef.self) { ref in
                VideoTextChapterView(chapter: ref.chapter, onOpen: { openRow($0) })
            }
            #if os(iOS)
            .fullScreenCover(item: $youtubeClip) { clip in
                FullScreenVideoCover(videoURL: clip.embedURL)
            }
            #elseif os(macOS)
            .sheet(item: $youtubeClip) { clip in
                youtubeClipCover(clip)
            }
            #endif
            .onReceive(NotificationCenter.default.publisher(for: .deepLinkArchive)) { note in
                guard let date = note.object as? Date else { return }
                shelf = .minute
                path.append(Self.dateString(from: date))
            }
        }
    }

    // MARK: - Minute shelf

    private var minuteShelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                selectedDateRow
                calendar
                    .frame(maxWidth: .infinity)
                fallOpenRow
            }
            .padding(20)
            .readableContentWidth()
        }
        .toolbar {
            ToolbarItem(placement: jumpPlacement) {
                Button("Today") {
                    withAnimation {
                        archiveCalendar.revealToday(now: Date(), availableDateStrings: datesWithReadings)
                    }
                }
            }
        }
    }

    private var calendar: some View {
        ArchiveCalendarView(
            selection: $archiveCalendar.selection,
            visibleMonth: $archiveCalendar.visibleMonth,
            availableDateStrings: datesWithReadings
        )
    }

    /// Every date that has at least one archived reading, as `yyyy-MM-dd`.
    private var datesWithReadings: Set<String> {
        Set(allReadings.map(\.dateString).filter { !$0.isEmpty })
    }

    /// When the reading for a day exists or will. A day with no rows is told
    /// when, not just that — the same sentence `ArchiveDateDetailView` shows
    /// once the reader taps through.
    private func availability(of dateString: String) -> MinuteSchedule.Availability {
        guard let day = LessonSchedule.day(from: dateString) else { return .unknown }
        return MinuteSchedule.availability(of: day, archived: datesWithReadings, today: Self.today())
    }

    private var selectedDateRow: some View {
        let dateString = Self.dateString(from: archiveCalendar.selection)
        let sentence = availability(of: dateString).sentence

        return Button {
            path.append(dateString)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.longDateString(from: archiveCalendar.selection))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(sentence ?? {
                        #if os(tvOS)
                        "Open readings"
                        #else
                        "Open video"
                        #endif
                    }())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.acimCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// A physical book falling open: a published Daily Minute if any have
    /// been fetched, otherwise a bundled Text passage so the gesture still
    /// has a page. Either way the picture starts; the day screen is not a
    /// reading.
    private var fallOpenRow: some View {
        Button(action: fallOpen) {
            HStack {
                Text("Let it fall open")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "book")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.acimCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
    }

    private var publishedMinuteDates: [String] {
        var seen = Set<String>()
        var dates: [String] = []
        for reading in allReadings where reading.channel == "daily-minute" {
            let key = reading.dateString
            if !key.isEmpty, seen.insert(key).inserted {
                dates.append(key)
            }
        }
        return dates
    }

    private var textSegmentIDs: [Int] {
        CorpusService.shared.allSegmentIDs.filter {
            CorpusService.shared.segment(id: $0)?.bookName == "Text"
        }
    }

    private func fallOpen() {
        let opening = FallOpen.opening(
            publishedDates: publishedMinuteDates,
            segmentIDs: textSegmentIDs,
            pickIndex: { Int.random(in: 0..<$0) }
        )
        switch opening {
        case .publishedMinute(let dateString):
            if let reading = allReadings.first(where: {
                $0.dateString == dateString && $0.channel == "daily-minute"
            }) {
                openRow(fromArchived: reading)
                return
            }
            path.append(dateString)
        case .bundledSegment(let id):
            if let segment = CorpusService.shared.segment(id: id) {
                openPlayer(.segment(segment))
            }
        case nil:
            break
        }
    }

    // MARK: - Lesson shelf

    private var lessonShelf: some View {
        List {
            ForEach(lessonCatalogue, id: \.id) { row in
                VideoPlayableRow(title: row.title, onTap: { openRow(row) })
                #if !os(tvOS)
                .listRowSeparator(.visible)
                #endif
            }
        }
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
                pendingJump = n
            }
        }
    }

    private var lessonCatalogue: [VideoLibrary.Row] {
        var titles: [Int: String] = WorkbookCatalog.all
        for lesson in lessons where !lesson.lessonTitle.isEmpty {
            titles[lesson.lessonNumber] = lesson.lessonTitle
        }
        var videoIDsByLesson: [Int: [String]] = [:]
        for n in 1...365 {
            let ids = youtubeIDs(forLesson: n)
            if !ids.isEmpty { videoIDsByLesson[n] = ids }
        }
        for intro in WorkbookBodiesCatalog.allIntroductions {
            let ids = youtubeIDs(forLesson: intro.lessonNumber)
            if !ids.isEmpty { videoIDsByLesson[intro.lessonNumber] = ids }
        }
        let intros = WorkbookBodiesCatalog.allIntroductions.map {
            (number: $0.lessonNumber, title: $0.title, insertBefore: $0.insertBefore)
        }
        return VideoLibrary.lessonRows(
            titles: titles,
            videoIDsByLesson: videoIDsByLesson,
            introductions: intros
        )
    }

    /// Jump-to-lesson must not present the player (or the YouTube cover)
    /// while the sheet is still up — nested presentations crash
    /// (ACIMDailyMinuteTV-2026-09-09-105807.ips).
    private func openPendingJump() {
        guard let n = pendingJump else { return }
        pendingJump = nil
        if let row = lessonCatalogue.first(where: { $0.id == "lesson:\(n)" }) {
            openRow(row)
            return
        }
        openRow(VideoLibrary.Row(
            id: "lesson:\(n)",
            title: WorkbookCatalog.title(for: n) ?? "Lesson \(n)",
            videoIDs: youtubeIDs(forLesson: n)
        ))
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

    // MARK: - Text / Manual shelves

    private var textShelf: some View {
        let corpus = CorpusService.shared
        return List {
            if corpus.textChapters.isEmpty {
                ContentUnavailableView {
                    Label("The Text is unavailable", systemImage: "book.closed")
                } description: {
                    Text("The bundled Text could not be read from this build.")
                }
                #if !os(tvOS)
                .listRowSeparator(.hidden)
                #endif
                .listRowBackground(Color.clear)
            } else {
                ForEach(corpus.textChapters) { chapter in
                    NavigationLink(value: VideoTextChapterRef(chapter: chapter.number)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(chapter.displayName)
                                .font(.system(.subheadline, design: .serif).weight(.semibold))
                            if let subtitle = chapter.subtitle {
                                Text(subtitle)
                                    .font(.acimCaption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(chapter.sections.count == 1 ? "1 section" : "\(chapter.sections.count) sections")
                                .font(.acimCaption2)
                                .foregroundStyle(.tertiary)
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

    private var manualShelf: some View {
        let corpus = CorpusService.shared
        let rows = VideoLibrary.manualSectionRows(
            sections: corpus.manualSections.map { (number: $0.number, title: $0.title) },
            videoIDsByNumber: [:]
        )
        return List {
            if rows.isEmpty {
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
                ForEach(Array(zip(corpus.manualSections, rows)), id: \.1.id) { section, row in
                    VideoPlayableRow(
                        title: row.title,
                        subtitle: section.stem,
                        onTap: { openRow(row) }
                    )
                    #if !os(tvOS)
                    .listRowSeparator(.visible)
                    #endif
                }
            }
        }
        .listStyle(.plain)
        .readableContentWidth()
    }

    // MARK: - Open

    private var youtubeAvailable: Bool {
        #if os(tvOS)
        false
        #else
        true
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private func youtubeClipCover(_ clip: VideoYouTubeClip) -> some View {
        NavigationStack {
            YouTubePlayerView(videoURL: clip.embedURL, autoplay: true)
                .navigationTitle(clip.title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { youtubeClip = nil }
                    }
                }
        }
    }
    #endif

    private func openRow(_ row: VideoLibrary.Row) {
        switch VideoLibrary.play(videoIDs: row.videoIDs, youtubeAvailable: youtubeAvailable) {
        case .youtube(let ids):
            #if os(iOS) || os(macOS)
            youtubeClip = VideoYouTubeClip(title: row.title, videoIDs: ids)
            #endif
        case .compose:
            openPlayer(playerItem(for: row))
        }
    }

    private func playerItem(for row: VideoLibrary.Row) -> TVPlayerItem {
        if row.id.hasPrefix("intro:") || row.id.hasPrefix("lesson:") {
            let number = LessonNarration.number(fromPlayerID: row.id) ?? 0
            return .workbookLesson(number)
        }
        if row.id.hasPrefix("text:"),
           let chapterPart = row.id.split(separator: ":").last?.split(separator: ".").first,
           let chapter = Int(chapterPart),
           let sectionPart = row.id.split(separator: ".").last,
           let section = Int(sectionPart) {
            return .textSection(chapter: chapter, section: section)
        }
        if row.id.hasPrefix("manual:"),
           let numberPart = row.id.split(separator: ":").last,
           let number = Int(numberPart) {
            return .manualSection(number: number)
        }
        return .workbookLesson(0)
    }

    private func openRow(fromArchived reading: ArchivedReading) {
        let ids = youtubeIDs(for: reading)
        switch VideoLibrary.play(videoIDs: ids, youtubeAvailable: youtubeAvailable) {
        case .youtube(let ids):
            #if os(iOS) || os(macOS)
            youtubeClip = VideoYouTubeClip(title: title(for: reading), videoIDs: ids)
            #endif
        case .compose:
            openPlayer(.archived(reading))
        }
    }

    private func title(for reading: ArchivedReading) -> String {
        if reading.channel == "daily-minute" { return "Daily Minute" }
        if let n = reading.lessonNumber { return "Lesson \(n)" }
        return "Lesson"
    }

    /// Minute: podcast `<link>` first — the daily JSON can still name
    /// yesterday. Lesson: daily JSON first — the archive row can keep a
    /// dead re-upload. Same ordering as `ArchiveDateDetailView`.
    private func youtubeIDs(for reading: ArchivedReading) -> [String] {
        if reading.channel == "daily-minute" {
            let day = reading.dateString
            let podcastIDs = podcasts.compactMap { episode -> String? in
                guard episode.channel == "minute" else { return nil }
                guard LessonSchedule.formatted(episode.publishedAt) == day else { return nil }
                return episode.youtubeURL
            }
            return YouTubeID.candidates(
                kind: .minute,
                archiveID: reading.youtubeID,
                dailyID: minutes.first(where: { $0.date == reading.dateString })?.youtubeID,
                podcastIDs: podcastIDs
            )
        }
        if let number = reading.lessonNumber {
            return youtubeIDs(forLesson: number)
        }
        return YouTubeID.candidates(
            kind: .minute,
            archiveID: reading.youtubeID,
            dailyID: nil,
            podcastIDs: []
        )
    }

    private func youtubeIDs(forLesson number: Int) -> [String] {
        let podcastIDs = podcasts.compactMap { episode -> String? in
            guard episode.channel == "lesson" else { return nil }
            guard LessonNarration.number(fromTitle: episode.title) == number else { return nil }
            return episode.youtubeURL
        }
        return YouTubeID.candidates(
            kind: .lesson,
            archiveID: allReadings.first(where: {
                $0.channel == "daily-lesson" && $0.lessonNumber == number
            })?.youtubeID,
            dailyID: lessons.first(where: { $0.lessonNumber == number })?.youtubeID,
            podcastIDs: podcastIDs
        )
    }

    // MARK: - Refresh

    @MainActor
    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Only reachable from `.refreshable`, so the user is explicitly asking
        // for fresh data: always force past the cooldown and the HTTP cache.
        let service = DataService(modelContainer: modelContext.container)
        do {
            async let minuteDTO = service.fetchDailyMinute(force: true)
            async let lessonDTO = service.fetchDailyLesson(force: true)
            let (m, l) = try await (minuteDTO, lessonDTO)
            if let m { try DataService.persistMinute(m, in: modelContext) }
            if let l { try DataService.persistLesson(l, in: modelContext) }
        } catch {
            // Offline or transient error — fall through silently; cached rows
            // remain visible. No separate error UX in this phase (matches the
            // Today-tab behavior).
        }
        await refreshPodcasts(force: true)
    }

    /// Historical Daily Minute JSON has no `youtube_id`. The podcast feed's
    /// `<link>` does. The Video tab plays those, so it cannot wait for the
    /// Listen tab to have been opened first.
    private func refreshPodcasts(force: Bool) async {
        let service = PodcastService()
        do {
            async let minutes = service.fetchMinuteEpisodes(force: force)
            async let lessons = service.fetchLessonEpisodes(force: force)
            let (m, l) = try await (minutes, lessons)
            try PodcastService.persist(m, channel: "minute", in: modelContext)
            try PodcastService.persist(l, channel: "lesson", in: modelContext)
        } catch {
            // Cached episodes, if any, still resolve a video.
        }
    }

    // MARK: - Date helpers

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f
    }()

    /// Midnight-UTC Date for today, matching ingestion timezone (see
    /// `DataService.parseISODate`).
    static func today() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.startOfDay(for: Date())
    }

    /// `Date → "yyyy-MM-dd"` in UTC, symmetric with `DataService.parseISODate`.
    static func dateString(from date: Date) -> String {
        dateParser.string(from: date)
    }

    /// `Date → "Thursday, April 10, 2026"` in the user's locale.
    static func longDateString(from date: Date) -> String {
        longFormatter.string(from: date)
    }
}

#if os(iOS) || os(macOS)
private struct VideoYouTubeClip: Identifiable {
    var id: String { title + ":" + videoIDs.joined(separator: ",") }
    let title: String
    let videoIDs: [String]

    var embedURL: String {
        let id = videoIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        return "https://www.youtube.com/embed/\(id)"
    }
}
#endif

// MARK: - Search results

/// In-memory filter + sort over the archive, extracted out of `ArchiveView`
/// so `@Query` re-evaluation stays independent of `searchText` keystrokes.
/// Mirrors the pattern used by `FilteredLessonsList` in the Lessons tab.
private struct ArchiveSearchResultsList: View {
    let query: String
    let readings: [ArchivedReading]
    @Binding var path: NavigationPath

    var body: some View {
        let results = filtered()

        Group {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    ForEach(results) { reading in
                        Button {
                            path.append(reading.dateString)
                        } label: {
                            row(for: reading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .readableContentWidth()
            }
        }
    }

    /// Filter contract (locked for Phase 3.7):
    ///   * Trimmed query matching `^\d{4}-\d{2}-\d{2}$` → exact `dateString` match.
    ///   * Otherwise → `searchableText.localizedStandardContains(query)`.
    /// Sort: `dateString` DESC (already pre-sorted by `@Query`), then `channel`
    /// DESC inside a date so `"daily-minute"` appears before `"daily-lesson"`.
    private func filtered() -> [ArchivedReading] {
        let matches: [ArchivedReading]
        if isIsoDate(query) {
            matches = readings.filter { $0.dateString == query }
        } else {
            matches = readings.filter {
                $0.searchableText.localizedStandardContains(query)
            }
        }

        return matches.sorted { lhs, rhs in
            if lhs.dateString != rhs.dateString {
                return lhs.dateString > rhs.dateString
            }
            return lhs.channel > rhs.channel
        }
    }

    private func isIsoDate(_ s: String) -> Bool {
        guard s.count == 10 else { return false }
        let parts = s.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2 else {
            return false
        }
        return parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }

    @ViewBuilder
    private func row(for reading: ArchivedReading) -> some View {
        let label = reading.channel == "daily-minute"
            ? "Daily Minute"
            : (reading.lessonNumber.flatMap { $0 > 0 ? "Lesson \($0)" : nil } ?? "Lesson")
        let snippet = snippet(for: reading)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(reading.dateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(snippet)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }

    /// First ~120 chars of whichever field reads best: `text` for minutes,
    /// the title (`text`) for lessons. Collapses internal whitespace so
    /// multi-line passages render cleanly as a snippet.
    private func snippet(for reading: ArchivedReading) -> String {
        let collapsed = reading.text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let trimmed = collapsed.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 120 else { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: 120)
        return trimmed[..<idx] + "…"
    }
}

#Preview {
    ArchiveView()
        .preferredColorScheme(.dark)
        .modelContainer(
            for: [ArchivedReading.self, Bookmark.self, DailyLesson.self, DailyMinute.self, CachedPodcastEpisode.self],
            inMemory: true
        )
}
