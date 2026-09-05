import SwiftUI
import SwiftData

/// Phase 3.6 — Listen tab.
///
/// Two independently-fetched podcast feeds (Daily Minute + Daily Lesson)
/// surface as a segmented picker above a newest-first episode list. Tapping
/// a row hands the URL to the root `AudioManager`, which drives the
/// reserved MiniPlayer overlay in `ContentView`. A 16:9 YouTube playlist
/// embed at the top switches between the Daily Minute and Daily Lesson
/// playlists based on the selected feed. The Lessons playlist remembers
/// the last-watched lesson index across launches via `@AppStorage`.
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

    @State private var selectedFeed: PodcastFeed = .minute
    /// Downloads live on disk, not in SwiftData, so nothing observes them.
    /// Bumping this is what tells the list a row's download state changed.
    @State private var downloadRevision = 0
    @State private var loadState: LoadState = .idle
    @State private var hasLoadedOnce = false
    #if os(iOS) || os(tvOS)
    @State private var videoRequest: VideoRequest?
    #endif

    @AppStorage("listen.lessons.lastWatchedIndex") private var lessonsLastWatchedIndex: Int = 1

    /// Bound to the same defaults key `PlaybackHistory` writes. Reading the
    /// store through a plain `static` accessor would give SwiftUI nothing to
    /// observe, so the check marks would not appear until the tab was rebuilt.
    @AppStorage(PlaybackHistory.defaultsKey) private var listenedData: Data = Data()

    private var listenedEpisodes: [String: Date] {
        _ = listenedData
        return PlaybackHistory.entries
    }

    private let dailyMinutePlaylistID = YouTubePlaylists.dailyMinute
    private let dailyLessonPlaylistID = YouTubePlaylists.dailyLesson

    private let service = PodcastService()

    private var currentEpisodes: [PodcastEpisode] {
        let source = (selectedFeed == .minute) ? cachedMinutes : cachedLessons
        return source.map { cached in
            let episode = cached.asEpisode()
            guard selectedFeed == .lesson,
                  let n = Self.lessonNumber(from: episode.title),
                  let canonical = WorkbookCatalog.title(for: n) else {
                return episode
            }
            return PodcastEpisode(
                id: episode.id,
                title: canonical,
                date: episode.date,
                audioURL: episode.audioURL,
                duration: episode.duration,
                youtubeURL: episode.youtubeURL
            )
        }
    }

    private static func lessonNumber(from title: String) -> Int? {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if trimmed == "Introduction" { return 0 }
        guard trimmed.hasPrefix("Lesson ") else { return nil }
        let digits = trimmed.dropFirst("Lesson ".count).prefix(while: \.isNumber)
        return Int(digits)
    }

    private var embedURL: URL? {
        switch selectedFeed {
        case .minute:
            return URL(string: "https://www.youtube.com/embed/videoseries?list=\(dailyMinutePlaylistID)")
        case .lesson:
            return URL(string: "https://www.youtube.com/embed/videoseries?list=\(dailyLessonPlaylistID)&index=\(lessonsLastWatchedIndex)")
        }
    }

    var body: some View {
        NavigationStack {
            List {
                #if os(iOS)
                if let url = embedURL {
                    Section {
                        youtubeCard(url: url.absoluteString)
                            .id(url)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            #if !os(tvOS)
                            .listRowSeparator(.hidden)
                            #endif
                            .listRowBackground(Color.clear)
                    }
                }
                #endif

                Section {
                    content
                } header: {
                    feedPicker
                }
            }
            .listStyle(.plain)
            .readableContentWidth()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
            }
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
            .task(id: selectedFeed) {
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
            .onChange(of: cachedLessons.count) { oldCount, newCount in
                if oldCount == 0 && newCount > 0 {
                    lessonsLastWatchedIndex = newCount
                }
            }
        }
    }

    // MARK: - YouTube

    // ⛔ iOS only, with its row above: the card is a WebKit embed.
    #if os(iOS)
    private func youtubeCard(url: String) -> some View {
        let title = selectedFeed == .minute ? "Daily Minute Playlist" : "Daily Lessons Playlist"
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            LiteYouTubeCard(
                videoID: leadVideoID,
                playerURL: url,
                accessibilityTitle: title
            )
        }
        .padding(16)
        .background(Color.acimCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    #endif

    /// The video the playlist embed will open on, whose thumbnail therefore
    /// stands in for the playlist. A `videoseries` URL carries no video id of
    /// its own, so it has to be recovered from the episode list.
    private var leadVideoID: String? {
        let list = currentEpisodes
        guard !list.isEmpty else { return nil }

        let episode: PodcastEpisode
        switch selectedFeed {
        case .minute:
            episode = list[0]
        case .lesson:
            // `lastWatchedIndex` is a 1-based position from the oldest end,
            // matching the `index=` parameter handed to the embed.
            let offset = list.count - lessonsLastWatchedIndex
            episode = list[min(max(offset, 0), list.count - 1)]
        }
        return YouTubeID.extract(from: episode.youtubeURL)
    }

    // MARK: - Feed picker

    private var feedPicker: some View {
        Picker("Feed", selection: $selectedFeed) {
            ForEach(PodcastFeed.allCases) { feed in
                Text(feed.label).tag(feed)
            }
        }
        #if !os(tvOS)
                .pickerStyle(.segmented)
                #endif
        .padding(.vertical, 8)
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
    }

    // MARK: - Episode content

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .idle, .loading:
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

        case .failed:
            ContentUnavailableView {
                Label("Can't reach podcast feed", systemImage: "wifi.slash")
            } description: {
                Text("Pull to retry.")
            }
            #if !os(tvOS)
            .listRowSeparator(.hidden)
            #endif
            .listRowBackground(Color.clear)

        case .loaded:
            let list = currentEpisodes
            if list.isEmpty {
                ContentUnavailableView {
                    Label("No episodes yet", systemImage: "waveform.slash")
                } description: {
                    Text("The \(selectedFeed.label) feed has not published any episodes.")
                }
                #if !os(tvOS)
                .listRowSeparator(.hidden)
                #endif
                .listRowBackground(Color.clear)
            } else {
                ForEach(Array(list.enumerated()), id: \.element.id) { offset, episode in
                    let playedAt = listenedEpisodes[episode.id]
                    PodcastEpisodeRow(
                        episode: episode,
                        feed: selectedFeed,
                        isPlaying: isCurrentlyPlaying(episode),
                        playedAt: playedAt,
                        onTap: {
                            if selectedFeed == .lesson {
                                lessonsLastWatchedIndex = list.count - offset
                            }
                            play(episode)
                        }
                    )
                    #if !os(tvOS)
                    .listRowSeparator(.visible)
                    #endif
                    #if !os(tvOS)
                    .swipeActions(edge: .trailing) {
                        Button {
                            PlaybackHistory.toggle(episode.id)
                        } label: {
                            Label(
                                playedAt == nil ? "Mark listened" : "Mark unplayed",
                                systemImage: playedAt == nil ? "checkmark.circle" : "circle"
                            )
                        }
                        .tint(playedAt == nil ? .green : .gray)

                        // Shown only when there is something to fetch. An
                        // affordance that cannot do anything is worse than no
                        // affordance, and today every episode is in that state.
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
            }
        }
    }

    // MARK: - Actions

    private func play(_ episode: PodcastEpisode) {
        // Opening is the only listened signal available: no MP3 is published
        // yet, so there is no playback position to measure against. A swipe
        // action undoes an accidental tap.
        PlaybackHistory.markPlayed(episode.id)

        // Audio is the intended experience; the video is what exists when no
        // MP3 has been published for this reading yet. Tapping play should do
        // something either way rather than silently failing.
        if let local = AudioDownloadStore.localURL(for: episode.id) {
            audio.play(url: local.absoluteString, title: episode.title)
            return
        }
        if !episode.audioURL.isEmpty {
            audio.play(url: episode.audioURL, title: episode.title)
            return
        }
        #if os(iOS) || os(tvOS)
        if !episode.youtubeURL.isEmpty {
            videoRequest = VideoRequest(id: episode.youtubeURL)
        }
        #endif
    }

    private func isCurrentlyPlaying(_ episode: PodcastEpisode) -> Bool {
        audio.hasActiveAudio && audio.currentTitle == episode.title
    }

    private func reload(force: Bool) async {
        let hasCache = !currentEpisodes.isEmpty

        if hasCache {
            loadState = .loaded
        }

        if hasCache && hasLoadedOnce && !force {
            return
        }

        if !hasCache { loadState = .loading }

        let minuteOK = await fetchAndPersistFeed(.minute, force: force)
        let lessonOK = await fetchAndPersistFeed(.lesson, force: force)

        let selectedOK = (selectedFeed == .minute) ? minuteOK : lessonOK
        loadState = (selectedOK || hasCache) ? .loaded : .failed
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

enum PodcastFeed: String, CaseIterable, Identifiable, Hashable {
    case minute
    case lesson

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minute: return "Minute"
        case .lesson: return "Lessons"
        }
    }
}

private enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed
}


#if os(iOS) || os(tvOS)
/// Wraps the URL so `fullScreenCover(item:)` has something `Identifiable` to
/// key on, without conforming `String` app-wide.
private struct VideoRequest: Identifiable {
    let id: String
    var url: String { id }
}
#endif
