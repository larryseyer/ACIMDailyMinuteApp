import SwiftUI
import SwiftData

/// Phase 3.6 — Listen tab.
///
/// Two independently-fetched podcast feeds (Daily Minute + Daily Lesson)
/// surface as a segmented picker above a newest-first episode list. Tapping
/// a row hands the URL to the root `AudioManager`, which drives the
/// reserved MiniPlayer overlay in `ContentView`. When today's Daily Minute
/// carries a `youtubeURL`, the feed is topped by an inline 16:9 embed so
/// the video and audio surfaces live side by side instead of behind
/// separate tabs.
///
/// The view deliberately holds episodes in `@State` rather than SwiftData:
/// podcast feeds are a discovery surface, not persisted content, and
/// `URLSession` already caches the XML against the publisher's
/// `Cache-Control: max-age=600`. Pull-to-refresh bypasses that cache via
/// `PodcastService.fetch(force: true)`.
struct ListenView: View {
    @Environment(AudioManager.self) private var audio
    @Environment(ConnectivityManager.self) private var connectivity
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DailyMinute.publishedAt, order: .reverse)
    private var minutes: [DailyMinute]

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

    private let service = PodcastService()

    private var currentEpisodes: [PodcastEpisode] {
        let source = (selectedFeed == .minute) ? cachedMinutes : cachedLessons
        return source.map { $0.asEpisode() }
    }

    private var todaysYouTubeURL: String? {
        guard let first = minutes.first,
              let url = first.youtubeURL,
              !url.isEmpty else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            List {
                if let youtube = todaysYouTubeURL {
                    Section {
                        youtubeCard(url: youtube)
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
        }
    }

    // MARK: - YouTube

    private func youtubeCard(url: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Minute — Video")
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
                ForEach(list) { episode in
                    PodcastEpisodeRow(
                        episode: episode,
                        isPlaying: isCurrentlyPlaying(episode),
                        onTap: { play(episode) }
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
        let feed = selectedFeed
        let hasCache = !currentEpisodes.isEmpty

        if hasCache && !force {
            loadState = .loaded
            hasLoadedOnce = true
            return
        }

        if !hasCache { loadState = .loading }
        do {
            let fetched: [PodcastEpisode]
            switch feed {
            case .minute:
                fetched = try await service.fetchMinuteEpisodes(force: force)
            case .lesson:
                fetched = try await service.fetchLessonEpisodes(force: force)
            }
            try PodcastService.persist(fetched, channel: feed.rawValue, in: modelContext)
            loadState = .loaded
            hasLoadedOnce = true
        } catch {
            if hasCache {
                loadState = .loaded
            } else {
                loadState = .failed
            }
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
