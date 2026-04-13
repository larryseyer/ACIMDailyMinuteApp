import SwiftUI

struct DigestView: View {
    @Environment(ConnectivityManager.self) private var connectivity
    @AppStorage("preferVideoMode") private var preferVideoMode = true
    @State private var episodes: [PodcastEpisode] = []
    @State private var selectedEpisodeId: String?
    @State private var youtubeURL: String?
    @State private var youtubePlaylist: [String: String] = [:]
    @State private var isLoading = true
    @State private var hasLoadedOnce = false

    /// Renders episode pubDates in the same GMT calendar day as the RSS
    /// `<title>`, not the device's local day. The Daily Digest is scheduled
    /// against UTC midnight — "April 7" has a pubDate of
    /// `2026-04-07 00:00:00 GMT`, which in Texas (CDT, UTC-5) falls on April 6
    /// at 19:00 local time. If we let the formatter slip into local time, the
    /// row title ("April 7") and the row subtitle ("Apr 6") disagree, which
    /// for an app whose brand promise is "Just the Facts" is worse than a
    /// cosmetic bug — it's a factual contradiction on screen.
    ///
    /// We use `DateFormatter` rather than `Date.FormatStyle(... timeZone:)`
    /// because the FormatStyle `timeZone` parameter has no observable effect
    /// for date-only styles (`time: .omitted`) in practice — the rendered
    /// date still reflects `Calendar.current.timeZone`. A plain
    /// `DateFormatter` with an explicit `.timeZone = .gmt` is unambiguous.
    ///
    /// `nonisolated(unsafe)` is defensible here: `DateFormatter` is
    /// documented-thread-safe for reads after iOS 7, and this instance is
    /// configured exactly once at first use and never mutated thereafter.
    nonisolated(unsafe) private static let episodeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeZone = .gmt
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pinnedHeader
                ScrollView {
                    episodesContent
                        .padding(.vertical, 8)
                }
                .refreshable {
                    guard connectivity.isConnected else { return }
                    await loadContent(force: true)
                }
            }
            .navigationTitle("Daily Digest")
            .task {
                // First view construction per process lifetime: force a fresh
                // fetch so a cold launch always surfaces the latest episode,
                // bypassing any `max-age=600` response still sitting in
                // `URLCache` from a previous session. Subsequent re-entries
                // into the Digest tab do not re-run this `.task` because
                // SwiftUI keeps TabView children alive, so the only way to
                // refetch after this point is pull-to-refresh.
                if !hasLoadedOnce {
                    await loadContent(force: true)
                    hasLoadedOnce = true
                }
            }
        }
    }

    // MARK: - Layout

    private var pinnedHeader: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $preferVideoMode) {
                Label("Video", systemImage: "video").tag(true)
                Label("Audio", systemImage: "headphones").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            if preferVideoMode {
                videoSection
            } else {
                audioSection
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var episodesContent: some View {
        if !episodes.isEmpty {
            episodesSection
        } else if !isLoading {
            Text("No episodes available")
                .font(.acimCaption)
                .foregroundStyle(.secondary)
                .padding(.top, 48)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Video

    private var currentVideoURL: String? {
        if let episode = currentEpisode {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            let dateKey = formatter.string(from: episode.date)
            if let playlistURL = youtubePlaylist[dateKey] {
                return playlistURL
            }
        }
        return youtubeURL
    }

    private var videoSection: some View {
        Group {
            if !connectivity.isConnected {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Video requires internet connection")
                        .font(.acimSubheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.11).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            } else if let videoURL = currentVideoURL {
                YouTubePlayerView(videoURL: videoURL)
                    .id(videoURL)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
            } else if isLoading {
                ProgressView("Loading video...")
                    .aspectRatio(16/9, contentMode: .fit)
            } else {
                Text("No video available")
                    .font(.acimSubheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            }
        }
    }

    // MARK: - Audio

    private var currentEpisode: PodcastEpisode? {
        if let selectedId = selectedEpisodeId {
            return episodes.first { $0.id == selectedId }
        }
        return episodes.first
    }

    private var audioSection: some View {
        Group {
            if let episode = currentEpisode {
                AudioPlayerView(audioURL: episode.audioURL, title: episode.title)
                    .id(episode.id)
                    .padding(.horizontal, 16)
            } else if isLoading {
                ProgressView("Loading audio...")
                    .frame(height: 200)
            } else {
                Text("No audio available today")
                    .font(.acimSubheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            }
        }
    }

    // MARK: - Episodes

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Episodes")
                .font(.acimHeadline)
                .padding(.horizontal, 16)

            // Show every episode, including the one currently loaded in the
            // player above. The previous design used `dropFirst()` to hide
            // the current episode on the assumption that it was already
            // "represented" by the player, but that turned the list into a
            // misleading "everything except what's playing" view — users
            // reasonably expected a complete episode index and read the top
            // row as the newest. Keeping every episode in the list, with the
            // currently-loaded one marked, removes the ambiguity.
            ForEach(episodes) { episode in
                episodeRow(episode)
            }
        }
    }

    private func episodeRow(_ episode: PodcastEpisode) -> some View {
        let isPlaying = episode.id == currentEpisode?.id
        return Button {
            selectedEpisodeId = episode.id
        } label: {
            HStack(spacing: 12) {
                // Leading indicator. We keep the 16pt slot reserved on every
                // row (via `.frame` + `.opacity`) so titles line up
                // vertically whether or not the row is the active one.
                Image(systemName: "speaker.wave.2.fill")
                    .font(.acimCaption)
                    .foregroundStyle(.tint)
                    .frame(width: 16)
                    .opacity(isPlaying ? 1 : 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.acimSubheadline)
                        .fontWeight(isPlaying ? .semibold : .regular)
                        .lineLimit(2)
                    Text(Self.episodeDateFormatter.string(from: episode.date))
                        .font(.acimCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !episode.duration.isEmpty {
                    Text(episode.duration)
                        .font(.acimCaption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isPlaying ? Color(white: 0.17).opacity(0.5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "\(episode.title), now playing" : episode.title)
    }

    // MARK: - Load

    /// Loads episodes, the daily video URL, and the historical YouTube
    /// playlist **independently and in parallel**.
    ///
    /// Each fetch is gated by its own `do/catch` so a single failure — say,
    /// the YouTube playlist scrape hitting a layout change on youtube.com —
    /// never hides successfully-fetched episodes or the video URL. This
    /// mirrors the resilience pattern we use in `StoriesView.refresh`.
    private func loadContent(force: Bool = false) async {
        defer { isLoading = false }
        let service = PodcastService()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    let eps = try await service.fetchEpisodes(force: force)
                    await MainActor.run { episodes = eps }
                } catch {
                    print("[DigestView] fetchEpisodes failed: \(String(reflecting: error))")
                }
            }
            group.addTask {
                do {
                    let url = try await service.fetchYouTubeURL()
                    await MainActor.run { youtubeURL = url }
                } catch {
                    print("[DigestView] fetchYouTubeURL failed: \(String(reflecting: error))")
                }
            }
            group.addTask {
                do {
                    let playlist = try await service.fetchYouTubePlaylist()
                    await MainActor.run { youtubePlaylist = playlist }
                } catch {
                    print("[DigestView] fetchYouTubePlaylist failed: \(String(reflecting: error))")
                }
            }
        }
    }
}

#Preview {
    DigestView()
        .preferredColorScheme(.dark)
}
