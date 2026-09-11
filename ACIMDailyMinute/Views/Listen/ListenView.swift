import SwiftUI
import SwiftData

/// Listen tab — activity, not a catalogue.
///
/// Now playing, part-finished, downloaded, finished. The Course stays
/// organised exactly once, in Read. Unplayed, undownloaded episodes do not
/// appear here: starting a reading is a Today or Read tap, and the session
/// shows up on this tab because `PlaybackProgress` records where it got to.
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

    /// Downloads live on disk, not in SwiftData, so nothing observes them.
    /// Bumping this is what tells the list a row's download state changed.
    @State private var downloadRevision = 0
    @State private var loadState: LoadState = .idle
    @State private var hasLoadedOnce = false
    #if os(iOS)
    @State private var videoRequest: VideoRequest?
    #endif
    #if os(tvOS)
    @Environment(\.openPlayer) private var openPlayer
    #endif

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

    private var allItems: [ListenItem] {
        let minutes = cachedMinutes.map {
            ListenItem(episode: $0.asEpisode(), feed: .minute)
        }
        let lessons = cachedLessons.map { cached -> ListenItem in
            let episode = cached.asEpisode()
            guard let n = Self.lessonNumber(from: episode.title),
                  let canonical = WorkbookCatalog.title(for: n) else {
                return ListenItem(episode: episode, feed: .lesson)
            }
            return ListenItem(
                episode: PodcastEpisode(
                    id: episode.id,
                    title: canonical,
                    date: episode.date,
                    audioURL: episode.audioURL,
                    duration: episode.duration,
                    youtubeURL: episode.youtubeURL
                ),
                feed: .lesson
            )
        }
        return minutes + lessons
    }

    private static func lessonNumber(from title: String) -> Int? {
        LessonNarration.number(fromTitle: title)
    }

    var body: some View {
        NavigationStack {
            List {
                content
            }
            .listStyle(.plain)
            .readableContentWidth()
            .navigationTitle("Listen")
            // ⛔ iOS only: the cover presents a WKWebView and tvOS has no WebKit.
            #if os(iOS)
            .fullScreenCover(item: $videoRequest) { request in
                FullScreenVideoCover(videoURL: request.url)
            }
            #endif

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

    // MARK: - Activity content

    @ViewBuilder
    private var content: some View {
        let buckets = activityBuckets
        switch loadState {
        case .idle, .loading:
            if buckets.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("Loading episodes…")
                        .padding(.vertical, 24)
                    Spacer()
                }
                #if !os(tvOS)
                .listRowSeparator(.hidden)
                #endif
                .listRowBackground(Color.clear)
            } else {
                activitySections(buckets)
            }

        case .failed:
            if buckets.isEmpty {
                ContentUnavailableView {
                    Label("Can't reach podcast feed", systemImage: "wifi.slash")
                } description: {
                    Text("Pull to retry.")
                }
                #if !os(tvOS)
                .listRowSeparator(.hidden)
                #endif
                .listRowBackground(Color.clear)
            } else {
                activitySections(buckets)
            }

        case .loaded:
            if buckets.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to resume", systemImage: "waveform")
                } description: {
                    Text("Start a reading from Today or Read, and it will show up here.")
                }
                #if !os(tvOS)
                .listRowSeparator(.hidden)
                #endif
                .listRowBackground(Color.clear)
            } else {
                activitySections(buckets)
            }
        }
    }

    @ViewBuilder
    private func activitySections(_ buckets: ActivityBuckets) -> some View {
        if !buckets.nowPlaying.isEmpty {
            Section("Now Playing") {
                ForEach(buckets.nowPlaying) { item in
                    episodeRow(item, playedAt: nil)
                }
            }
        }
        if !buckets.inProgress.isEmpty {
            Section("Part finished") {
                ForEach(buckets.inProgress) { item in
                    episodeRow(item, playedAt: nil)
                }
            }
        }
        if !buckets.downloaded.isEmpty {
            Section("Downloaded") {
                ForEach(buckets.downloaded) { item in
                    episodeRow(item, playedAt: nil)
                }
            }
        }
        if !buckets.finished.isEmpty {
            Section("Finished") {
                ForEach(buckets.finished) { item in
                    episodeRow(item, playedAt: listenedEpisodes[item.episode.id])
                }
            }
        }
    }

    @ViewBuilder
    private func episodeRow(_ item: ListenItem, playedAt: Date?) -> some View {
        let episode = item.episode
        PodcastEpisodeRow(
            episode: episode,
            feed: item.feed,
            isActive: isActive(episode),
            isPlaying: audio.isPlaying,
            playedAt: playedAt,
            onTap: {
                #if os(tvOS)
                presentEpisode(item)
                #else
                play(episode)
                #endif
            }
        )
        #if !os(tvOS)
        .listRowSeparator(.visible)
        .swipeActions(edge: .trailing) {
            let listened = PlaybackHistory.playedAt(episode.id)
            Button {
                toggleListened(episode)
            } label: {
                Label(
                    listened == nil ? "Mark listened" : "Mark unplayed",
                    systemImage: listened == nil ? "checkmark.circle" : "circle"
                )
            }
            .tint(listened == nil ? .green : .gray)

            if !episode.audioURL.isEmpty {
                if AudioDownloadStore.isDownloaded(episode.id) {
                    Button {
                        AudioDownloadStore.delete(episode.id)
                        downloadRevision += 1
                    } label: {
                        Label("Remove download", systemImage: "trash")
                    }
                    .tint(.orange)
                } else {
                    Button {
                        let id = episode.id
                        let remote = episode.audioURL
                        Task {
                            try? await AudioDownloadStore.download(
                                episodeID: id,
                                remoteURL: remote
                            )
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
        .id("\(episode.id)-\(downloadRevision)")
    }

    // MARK: - Buckets

    private var activityBuckets: ActivityBuckets {
        _ = downloadRevision
        var nowPlaying: [ListenItem] = []
        var inProgress: [ListenItem] = []
        var downloaded: [ListenItem] = []
        var finished: [ListenItem] = []

        var seenActive = false
        for item in allItems {
            switch activity(for: item.episode) {
            case .nowPlaying:
                nowPlaying.append(item)
                seenActive = true
            case .inProgress:
                inProgress.append(item)
            case .downloaded:
                downloaded.append(item)
            case .finished:
                finished.append(item)
            case nil:
                break
            }
        }

        // A session started from Today may not match a cached enclosure yet.
        // The mini player is still activity, so it belongs at the top.
        if audio.hasActiveAudio, !seenActive {
            nowPlaying.append(ListenItem(
                episode: PodcastEpisode(
                    id: audio.currentEpisodeID.isEmpty ? audio.currentURL : audio.currentEpisodeID,
                    title: audio.currentTitle,
                    date: .distantPast,
                    audioURL: audio.currentURL,
                    duration: "",
                    youtubeURL: ""
                ),
                feed: .minute
            ))
        }

        inProgress.sort { lhs, rhs in
            let l = progress(for: lhs.episode)?.updatedAt ?? .distantPast
            let r = progress(for: rhs.episode)?.updatedAt ?? .distantPast
            return l > r
        }
        downloaded.sort { $0.episode.date > $1.episode.date }
        finished.sort { lhs, rhs in
            let l = listenedEpisodes[lhs.episode.id] ?? progress(for: lhs.episode)?.updatedAt ?? .distantPast
            let r = listenedEpisodes[rhs.episode.id] ?? progress(for: rhs.episode)?.updatedAt ?? .distantPast
            return l > r
        }

        return ActivityBuckets(
            nowPlaying: nowPlaying,
            inProgress: inProgress,
            downloaded: downloaded,
            finished: finished
        )
    }

    private func activity(for episode: PodcastEpisode) -> ListenActivity? {
        ListenActivity.classify(
            isActive: isActive(episode) || matchesCurrentSession(episode),
            progress: progress(for: episode),
            listenedAt: listenedEpisodes[episode.id],
            isDownloaded: AudioDownloadStore.isDownloaded(episode.id)
        )
    }

    private func progress(for episode: PodcastEpisode) -> PlaybackProgress? {
        if let byID = progressEntries[episode.id] { return byID }
        guard !episode.audioURL.isEmpty else { return nil }
        return progressEntries[AudioManager.resolve(episode.audioURL)]
    }

    /// URL identity can disagree with a download's file:// URL; the stored
    /// episode id is the durable match.
    private func matchesCurrentSession(_ episode: PodcastEpisode) -> Bool {
        guard audio.hasActiveAudio, !audio.currentEpisodeID.isEmpty else { return false }
        if audio.currentEpisodeID == episode.id { return true }
        if !episode.audioURL.isEmpty,
           audio.currentEpisodeID == AudioManager.resolve(episode.audioURL) {
            return true
        }
        return false
    }

    // MARK: - Actions

    private func play(_ episode: PodcastEpisode) {
        // Audio is the intended experience; the video is what exists when no
        // MP3 has been published for this reading yet. Tapping play should do
        // something either way rather than silently failing.
        //
        // playOrToggle is the Today-header path: a second tap on the active
        // episode pauses instead of restarting from the beginning. Listened
        // is recorded only when a new session starts, not when one pauses.
        if let url = playbackURL(for: episode) {
            if !audio.isActive(url: url) {
                PlaybackHistory.markPlayed(episode.id)
            }
            audio.playOrToggle(url: url, title: episode.title, episodeID: episode.id)
            return
        }
        PlaybackHistory.markPlayed(episode.id)
        #if os(iOS)
        if !episode.youtubeURL.isEmpty {
            videoRequest = VideoRequest(id: episode.youtubeURL)
        }
        #endif
    }

    private func toggleListened(_ episode: PodcastEpisode) {
        if PlaybackHistory.playedAt(episode.id) != nil {
            PlaybackHistory.clear(episode.id)
            PlaybackProgressStore.clear(episode.id)
            if !episode.audioURL.isEmpty {
                PlaybackProgressStore.clear(AudioManager.resolve(episode.audioURL))
            }
        } else {
            PlaybackHistory.markPlayed(episode.id)
        }
    }

    /// Local download if present, otherwise the feed enclosure. Identity for
    /// `isActive` / `playOrToggle` is this string, not the episode title —
    /// every Daily Minute is titled "Daily Minute".
    private func playbackURL(for episode: PodcastEpisode) -> String? {
        if let local = AudioDownloadStore.localURL(for: episode.id) {
            return local.absoluteString
        }
        if !episode.audioURL.isEmpty { return episode.audioURL }
        return nil
    }

    #if os(tvOS)
    /// Select starts the composed player rather than handing the URL to a
    /// YouTube view tvOS cannot host. Passage text comes from the archive,
    /// today's feed, or the bundled Workbook — the episode itself carries none.
    private func presentEpisode(_ item: ListenItem) {
        let episode = item.episode
        PlaybackHistory.markPlayed(episode.id)
        let audioURL = playbackURL(for: episode)
        switch item.feed {
        case .minute:
            let day = Self.utcDayString(from: episode.date)
            let text = minutePassage(on: day)
            openPlayer(TVPlayerItem(
                id: "listen:\(episode.id)",
                eyebrow: "Daily Minute",
                title: nil,
                text: text.isEmpty ? episode.title : text,
                citation: nil,
                audioURL: audioURL,
                artName: "PlayerArt"
            ))
        case .lesson:
            let number = Self.lessonNumber(from: episode.title) ?? 0
            let passage = lessonPassage(number: number, fallbackTitle: episode.title)
            openPlayer(TVPlayerItem(
                id: "listen:\(episode.id)",
                eyebrow: WorkbookBodiesCatalog.isIntroduction(number) ? "Introduction" : "Lesson \(number)",
                title: passage.title,
                text: passage.body,
                citation: nil,
                audioURL: audioURL,
                artName: "PlayerArtLesson"
            ))
        }
    }

    private func minutePassage(on day: String) -> String {
        let archive = FetchDescriptor<ArchivedReading>(
            predicate: #Predicate { $0.channel == "daily-minute" && $0.dateString == day }
        )
        if let row = try? modelContext.fetch(archive).first, !row.text.isEmpty {
            return row.text
        }
        let today = FetchDescriptor<DailyMinute>(
            predicate: #Predicate { $0.date == day }
        )
        if let row = try? modelContext.fetch(today).first {
            return row.text
        }
        return ""
    }

    private func lessonPassage(number: Int, fallbackTitle: String) -> (title: String?, body: String) {
        let published = FetchDescriptor<DailyLesson>(
            predicate: #Predicate { $0.lessonNumber == number }
        )
        if let row = try? modelContext.fetch(published).first {
            return (row.lessonTitle, row.text)
        }
        if let intro = WorkbookBodiesCatalog.introduction(for: number) {
            return (intro.title, intro.body)
        }
        let title = WorkbookCatalog.title(for: number) ?? fallbackTitle
        let body = WorkbookBodiesCatalog.body(for: number) ?? title
        return (title, body)
    }

    private static func utcDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    #endif

    private func isActive(_ episode: PodcastEpisode) -> Bool {
        guard let url = playbackURL(for: episode) else { return false }
        if audio.isActive(url: url) { return true }
        return matchesCurrentSession(episode)
    }

    private func reload(force: Bool) async {
        let hasCache = !allItems.isEmpty

        if hasCache {
            loadState = .loaded
        }

        if hasCache && hasLoadedOnce && !force {
            return
        }

        if !hasCache { loadState = .loading }

        let minuteOK = await fetchAndPersistFeed(.minute, force: force)
        let lessonOK = await fetchAndPersistFeed(.lesson, force: force)

        loadState = (minuteOK || lessonOK || hasCache) ? .loaded : .failed
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

private struct ListenItem: Identifiable {
    var episode: PodcastEpisode
    var feed: PodcastFeed
    var id: String { episode.id }
}

private struct ActivityBuckets {
    var nowPlaying: [ListenItem]
    var inProgress: [ListenItem]
    var downloaded: [ListenItem]
    var finished: [ListenItem]

    var isEmpty: Bool {
        nowPlaying.isEmpty && inProgress.isEmpty && downloaded.isEmpty && finished.isEmpty
    }
}

private enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed
}


#if os(iOS)
/// Wraps the URL so `fullScreenCover(item:)` has something `Identifiable` to
/// key on, without conforming `String` app-wide.
private struct VideoRequest: Identifiable {
    let id: String
    var url: String { id }
}
#endif
