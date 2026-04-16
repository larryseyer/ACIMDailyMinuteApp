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
    @State private var loadState: LoadState = .idle
    @State private var hasLoadedOnce = false

    @AppStorage("listen.lessons.lastWatchedIndex") private var lessonsLastWatchedIndex: Int = 1

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
                duration: episode.duration
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
                if let url = embedURL {
                    Section {
                        youtubeCard(url: url.absoluteString)
                            .id(url)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    content
                } header: {
                    feedPicker
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
            }
            .navigationTitle("Listen")
            .refreshable {
                await reload(force: true)
            }
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

    private func youtubeCard(url: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedFeed == .minute ? "Daily Minute Playlist" : "Daily Lessons Playlist")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            YouTubePlayerView(videoURL: url)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Feed picker

    private var feedPicker: some View {
        Picker("Feed", selection: $selectedFeed) {
            ForEach(PodcastFeed.allCases) { feed in
                Text(feed.label).tag(feed)
            }
        }
        .pickerStyle(.segmented)
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
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

        case .failed:
            ContentUnavailableView {
                Label("Can't reach podcast feed", systemImage: "wifi.slash")
            } description: {
                Text("Pull to retry.")
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

        case .loaded:
            let list = currentEpisodes
            if list.isEmpty {
                ContentUnavailableView {
                    Label("No episodes yet", systemImage: "waveform.slash")
                } description: {
                    Text("The \(selectedFeed.label) feed has not published any episodes.")
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(Array(list.enumerated()), id: \.element.id) { offset, episode in
                    PodcastEpisodeRow(
                        episode: episode,
                        isPlaying: isCurrentlyPlaying(episode),
                        onTap: {
                            if selectedFeed == .lesson {
                                lessonsLastWatchedIndex = list.count - offset
                            }
                            play(episode)
                        }
                    )
                    .listRowSeparator(.visible)
                }
            }
        }
    }

    // MARK: - Actions

    private func play(_ episode: PodcastEpisode) {
        audio.play(url: episode.audioURL, title: episode.title)
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
