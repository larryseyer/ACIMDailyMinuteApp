import SwiftUI
import SwiftData

/// Listen tab — the Course in voice.
///
/// Same four shelves as Read (`CourseShelf`). Activity is a ribbon above
/// the shelf, not the tab. Unplayed audio is visible. A row with no MP3
/// still appears; play is omitted. YouTube and the composed player are
/// Video, not this tab.
///
/// A row hands the URL to the root `AudioManager` through `playOrToggle`,
/// the same path the Today header uses, so a second tap pauses. ContentView
/// hides the floating mini player on this tab (a tap there only switches
/// here), so this view draws `MiniPlayerView` in the bottom inset itself.
struct ListenView: View {
    @Environment(AudioManager.self) private var audio
    @Environment(ConnectivityManager.self) private var connectivity
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<CachedPodcastEpisode> { $0.channel == "minute" },
        sort: \CachedPodcastEpisode.publishedAt,
        order: .reverse
    )
    private var cachedMinutes: [CachedPodcastEpisode]

    @Query(
        filter: #Predicate<CachedPodcastEpisode> { $0.channel == "lesson" },
        sort: \CachedPodcastEpisode.publishedAt,
        order: .reverse
    )
    private var cachedLessons: [CachedPodcastEpisode]

    @Query(sort: \DailyLesson.lessonNumber) private var lessons: [DailyLesson]
    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-lesson" },
        sort: \ArchivedReading.lessonNumber
    )
    private var archivedLessons: [ArchivedReading]

    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-minute" },
        sort: \ArchivedReading.dateString
    )
    private var archivedMinutes: [ArchivedReading]
    @Query private var storedMinutes: [DailyMinute]

    /// Downloads live on disk, not in SwiftData, so nothing observes them.
    /// Bumping this is what tells the list a row's download state changed.
    @State private var downloadRevision = 0
    @State private var hasLoadedOnce = false
    @State private var shelf: CourseShelf = .lesson
    @State private var minuteCalendar = ArchiveCalendarState.starting(now: Date())
    @State private var path = NavigationPath()

    /// Bound to the same defaults key `PlaybackHistory` writes. Reading the
    /// store through a plain `static` accessor would give SwiftUI nothing to
    /// observe, so the check marks would not appear until the tab was rebuilt.
    @AppStorage(PlaybackHistory.defaultsKey) private var listenedData: Data = Data()
    @AppStorage(PlaybackProgressStore.defaultsKey) private var progressData: Data = Data()

    private var listenedEpisodes: [String: Date] {
        _ = listenedData
        return PlaybackHistory.entries
    }

    private var progressEntries: [String: PlaybackProgress] {
        _ = progressData
        return PlaybackProgressStore.entries
    }

    private let service = PodcastService()

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

                if let item = resumeItem {
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

                Group {
                    switch shelf {
                    case .minute: minuteShelf
                    case .lesson: lessonShelf
                    case .text: textShelf
                    case .manual: manualShelf
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Listen")
            .navigationDestination(for: ListenTextChapterRef.self) { ref in
                ListenTextChapterView(
                    chapter: ref.chapter,
                    played: listenedEpisodes,
                    isPlaying: audio.isPlaying,
                    isActive: { isActive($0) },
                    onPlay: { play(url: $0.audioURL, title: $0.title, episodeID: $0.episodeID) }
                )
            }
            #if !os(tvOS)
            .refreshable {
                await reload(force: true)
            }
            #endif
            .task {
                await reload(force: false)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, hasLoadedOnce else { return }
                Task { await reload(force: false) }
            }
            .onChange(of: connectivity.isConnected) { oldValue, newValue in
                guard !oldValue, newValue, hasLoadedOnce else { return }
                Task { await reload(force: true) }
            }
        }
        // ContentView hides the overlay on this tab (a tap there only
        // switches here), so the bar has to be drawn on the stack itself —
        // full width, above the tab bar, not inside the readable column.
        #if !os(tvOS)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if audio.hasActiveAudio {
                MiniPlayerView()
            }
        }
        #endif
    }

    // MARK: - Resume

    private var resumeItem: ListenLibrary.Resume? {
        _ = downloadRevision
        let inProgress: [(title: String, audioURL: String, episodeID: String, updatedAt: Date)] =
            resumeCandidates.compactMap { row in
                let classified = ListenActivity.classify(
                    isActive: isActive(row),
                    progress: progress(for: row),
                    listenedAt: listenedEpisodes[row.episodeID],
                    isDownloaded: AudioDownloadStore.isDownloaded(row.episodeID)
                )
                guard classified == .inProgress,
                      let updated = progress(for: row)?.updatedAt
                else { return nil }
                return (row.title, row.audioURL, row.episodeID, updated)
            }
        return ListenLibrary.resume(
            hasActiveAudio: audio.hasActiveAudio,
            nowPlayingTitle: audio.currentTitle,
            nowPlayingURL: audio.currentURL,
            nowPlayingEpisodeID: audio.currentEpisodeID,
            inProgress: inProgress
        )
    }

    private var resumeCandidates: [ListenLibrary.Row] {
        let minutes = cachedMinutes.map { cached in
            ListenLibrary.Row(
                id: cached.id,
                title: cached.title,
                audioURL: cached.audioURL,
                episodeID: cached.id
            )
        }
        let lessons = cachedLessons.map { cached -> ListenLibrary.Row in
            let number = LessonNarration.number(fromGUID: cached.id)
                ?? LessonNarration.number(fromTitle: cached.title)
            let title: String
            if let number, let canonical = WorkbookCatalog.title(for: number) {
                title = canonical
            } else {
                title = cached.title
            }
            return ListenLibrary.Row(
                id: cached.id,
                title: title,
                audioURL: cached.audioURL,
                episodeID: cached.id
            )
        }
        return minutes + lessons
    }

    // MARK: - Minute shelf

    private var minuteDates: Set<String> {
        var dates = Set(archivedMinutes.map(\.dateString).filter { !$0.isEmpty })
        for minute in storedMinutes where !minute.date.isEmpty {
            dates.insert(minute.date)
        }
        return dates
    }

    private var minuteShelf: some View {
        let row = minuteRow(for: ArchiveView.dateString(from: minuteCalendar.selection))
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ListenPlayableRow(
                    row: row,
                    isActive: isActive(row),
                    isPlaying: audio.isPlaying,
                    playedAt: listenedEpisodes[row.episodeID],
                    unrecordedCaption: minuteCaption(for: row),
                    onTap: { play(url: row.audioURL, title: row.title, episodeID: row.episodeID) }
                )

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
        let podcast = cachedMinutes.first { Self.utcDayString(from: $0.publishedAt) == dateString }
        let audioURL = ListenLibrary.minuteAudio(
            daily: daily,
            archived: archived,
            podcast: podcast?.audioURL
        )
        let episodeID = podcast?.id ?? dateString
        return ListenLibrary.Row(
            id: "minute:\(dateString)",
            title: ArchiveView.longDateString(from: minuteCalendar.selection),
            audioURL: audioURL,
            episodeID: episodeID
        )
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

    private static func utcDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Lesson shelf

    private var lessonShelf: some View {
        List {
            ForEach(lessonCatalogue, id: \.id) { row in
                listenRow(row)
            }
        }
        .listStyle(.plain)
        .readableContentWidth()
    }

    private var lessonCatalogue: [ListenLibrary.Row] {
        var audio: [Int: String] = [:]
        var ids: [Int: String] = [:]
        let podcasts = cachedLessons.map { (id: $0.id, title: $0.title, audioURL: $0.audioURL) }
        for n in 0...365 {
            let daily = lessons.first { $0.lessonNumber == n }?.audioURL
            let archived = archivedLessons.first { $0.lessonNumber == n }?.audioURL
            let podcast = LessonNarration.podcastURL(forLesson: n, episodes: podcasts)
            let url = LessonNarration.url(daily: daily, archived: archived, podcast: podcast) ?? ""
            if ListenLibrary.showsPlay(audioURL: url) {
                audio[n] = url
                if let episode = cachedLessons.first(where: {
                    LessonNarration.number(fromGUID: $0.id) == n
                        || LessonNarration.number(fromTitle: $0.title) == n
                }) {
                    ids[n] = episode.id
                }
            }
        }
        var titles: [Int: String] = WorkbookCatalog.all
        for lesson in lessons where !lesson.lessonTitle.isEmpty {
            titles[lesson.lessonNumber] = lesson.lessonTitle
        }
        let intros = WorkbookBodiesCatalog.allIntroductions.map {
            (number: $0.lessonNumber, title: $0.title, insertBefore: $0.insertBefore)
        }
        return ListenLibrary.lessonRows(
            titles: titles,
            audioByLesson: audio,
            episodeIDByLesson: ids,
            introductions: intros
        )
    }

    @ViewBuilder
    private func listenRow(_ row: ListenLibrary.Row) -> some View {
        ListenPlayableRow(
            row: row,
            isActive: isActive(row),
            isPlaying: audio.isPlaying,
            playedAt: listenedEpisodes[row.episodeID],
            unrecordedCaption: caption(for: row),
            onTap: { play(url: row.audioURL, title: row.title, episodeID: row.episodeID) }
        )
        #if !os(tvOS)
        .listRowSeparator(.visible)
        .swipeActions(edge: .trailing) {
            if ListenLibrary.showsPlay(audioURL: row.audioURL) {
                let listened = PlaybackHistory.playedAt(row.episodeID)
                Button {
                    toggleListened(episodeID: row.episodeID, audioURL: row.audioURL)
                } label: {
                    Label(
                        listened == nil ? "Mark listened" : "Mark unplayed",
                        systemImage: listened == nil ? "checkmark.circle" : "circle"
                    )
                }
                .tint(listened == nil ? .green : .gray)

                if AudioDownloadStore.isDownloaded(row.episodeID) {
                    Button {
                        AudioDownloadStore.delete(row.episodeID)
                        downloadRevision += 1
                    } label: {
                        Label("Remove download", systemImage: "trash")
                    }
                    .tint(.orange)
                } else {
                    Button {
                        let id = row.episodeID
                        let remote = row.audioURL
                        Task {
                            try? await AudioDownloadStore.download(episodeID: id, remoteURL: remote)
                            downloadRevision += 1
                        }
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    .tint(.blue)
                }
            }
        }
        #endif
        .id("\(row.id)-\(downloadRevision)")
    }

    // MARK: - Text and Manual shelves

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
                    NavigationLink(value: ListenTextChapterRef(chapter: chapter.number)) {
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
        let rows = ListenLibrary.manualSectionRows(
            sections: corpus.manualSections.map { (number: $0.number, title: $0.title) },
            audioByNumber: [:],
            episodeIDByNumber: [:]
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
                ForEach(rows, id: \.id) { row in
                    listenRow(row)
                }
            }
        }
        .listStyle(.plain)
        .readableContentWidth()
    }

    // MARK: - Actions

    private func caption(for row: ListenLibrary.Row) -> String? {
        guard !ListenLibrary.showsPlay(audioURL: row.audioURL) else { return nil }
        if row.id.hasPrefix("lesson:") || row.id.hasPrefix("intro:") {
            let number = LessonNarration.number(fromPlayerID: row.id) ?? 0
            let anchor = recordedAnchor()
            if let date = anchor.date,
               let available = LessonSchedule.availabilityDate(
                for: number,
                latestRecorded: anchor.number,
                latestDate: date
               ) {
                return ListenLibrary.unrecordedCaption(
                    availableOnFormatted: LessonSchedule.formatted(available)
                )
            }
        }
        return ListenLibrary.unrecordedCaption(availableOnFormatted: nil)
    }

    private func minuteCaption(for row: ListenLibrary.Row) -> String? {
        guard !ListenLibrary.showsPlay(audioURL: row.audioURL) else { return nil }
        let dateString = ArchiveView.dateString(from: minuteCalendar.selection)
        guard let day = LessonSchedule.day(from: dateString) else {
            return ListenLibrary.unrecordedCaption(availableOnFormatted: nil)
        }
        return MinuteSchedule.availability(
            of: day,
            archived: minuteDates,
            today: ArchiveView.today()
        ).sentence ?? ListenLibrary.unrecordedCaption(availableOnFormatted: nil)
    }

    private func recordedAnchor() -> (number: Int, date: Date?) {
        let anchor = LessonSchedule.anchor(
            from: lessons.map { ($0.lessonNumber, $0.publishedAt) }
                + archivedLessons.map { ($0.lessonNumber ?? 0, $0.timestamp) }
        )
        return (anchor?.number ?? 0, anchor?.date)
    }

    private func play(url: String, title: String, episodeID: String) {
        guard ListenLibrary.showsPlay(audioURL: url) else { return }
        let resolved = playbackURL(forAudio: url, episodeID: episodeID) ?? url
        if !audio.isActive(url: resolved) {
            PlaybackHistory.markPlayed(episodeID)
        }
        audio.playOrToggle(url: resolved, title: title, episodeID: episodeID)
    }

    private func toggleListened(episodeID: String, audioURL: String) {
        if PlaybackHistory.playedAt(episodeID) != nil {
            PlaybackHistory.clear(episodeID)
            PlaybackProgressStore.clear(episodeID)
            if ListenLibrary.showsPlay(audioURL: audioURL) {
                PlaybackProgressStore.clear(AudioManager.resolve(audioURL))
            }
        } else {
            PlaybackHistory.markPlayed(episodeID)
        }
    }

    private func playbackURL(forAudio remote: String, episodeID: String) -> String? {
        if let local = AudioDownloadStore.localURL(for: episodeID) {
            return local.absoluteString
        }
        if ListenLibrary.showsPlay(audioURL: remote) { return remote }
        return nil
    }

    private func isActive(_ row: ListenLibrary.Row) -> Bool {
        guard let url = playbackURL(forAudio: row.audioURL, episodeID: row.episodeID) else {
            return matchesCurrentSession(row)
        }
        if audio.isActive(url: url) { return true }
        return matchesCurrentSession(row)
    }

    private func matchesCurrentSession(_ row: ListenLibrary.Row) -> Bool {
        guard audio.hasActiveAudio, !audio.currentEpisodeID.isEmpty else { return false }
        if audio.currentEpisodeID == row.episodeID { return true }
        if ListenLibrary.showsPlay(audioURL: row.audioURL),
           audio.currentEpisodeID == AudioManager.resolve(row.audioURL) {
            return true
        }
        return false
    }

    private func progress(for row: ListenLibrary.Row) -> PlaybackProgress? {
        if let byID = progressEntries[row.episodeID] { return byID }
        guard ListenLibrary.showsPlay(audioURL: row.audioURL) else { return nil }
        return progressEntries[AudioManager.resolve(row.audioURL)]
    }

    private func reload(force: Bool) async {
        let hasCache = !cachedMinutes.isEmpty || !cachedLessons.isEmpty
        if hasCache && hasLoadedOnce && !force {
            return
        }
        _ = await fetchAndPersistFeed(.minute, force: force)
        _ = await fetchAndPersistFeed(.lesson, force: force)
        hasLoadedOnce = true
    }

    private func fetchAndPersistFeed(_ feed: PodcastFeed, force: Bool) async -> Bool {
        do {
            let fetched: [PodcastEpisode]
            switch feed {
            case .minute:
                fetched = try await service.fetchMinuteEpisodes(force: force)
            case .lesson:
                fetched = try await service.fetchLessonEpisodes(force: force)
            }
            try PodcastService.persist(fetched, channel: feed.rawValue, in: modelContext)
            return !fetched.isEmpty
        } catch let PodcastError.unparseableFeed(partial) {
            if !partial.isEmpty {
                try? PodcastService.persist(partial, channel: feed.rawValue, in: modelContext)
                return true
            }
            return false
        } catch {
            return false
        }
    }
}

// MARK: - Feed + load state

enum PodcastFeed: String, Hashable {
    case minute
    case lesson
}
