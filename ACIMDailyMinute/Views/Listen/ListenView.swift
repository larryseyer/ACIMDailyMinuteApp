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

    /// Downloads live on disk, not in SwiftData, so nothing observes them.
    /// Bumping this is what tells the list a row's download state changed.
    @State private var downloadRevision = 0
    @State private var loadState: LoadState = .idle
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
                    case .minute: EmptyView()
                    case .lesson: EmptyView()
                    case .text: EmptyView()
                    case .manual: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Listen")
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

    // MARK: - Actions

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

private enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed
}
