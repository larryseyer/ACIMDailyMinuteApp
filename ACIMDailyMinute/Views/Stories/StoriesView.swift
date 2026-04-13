import SwiftUI
import SwiftData

struct StoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ConnectivityManager.self) private var connectivity
    @Query(sort: \Story.publishedAt, order: .reverse) private var stories: [Story]
    @Query private var corrections: [Correction]
    @Query private var sources: [Source]
    @Query private var bookmarks: [Bookmark]
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var showOfflineToast = false
    @State private var watchTermMatchCount = 0

    var body: some View {
        NavigationStack {
            Group {
                if stories.isEmpty && !hasLoadedOnce && !connectivity.isConnected {
                    offlineEmptyView
                } else if stories.isEmpty && !hasLoadedOnce {
                    loadingView
                } else if stories.isEmpty {
                    emptyView
                } else {
                    storyList
                }
            }
            .navigationDestination(for: Story.self) { story in
                let correction = corrections.first { $0.storyId == story.id }
                StoryDetailView(story: story, sources: sources, correction: correction)
            }
            .navigationTitle("ACIM Daily Minute")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .task {
            if !hasLoadedOnce {
                // First view construction per process lifetime: force a fresh
                // fetch so a cold launch always surfaces the latest stories,
                // corrections, and source metadata regardless of any in-session
                // cooldown state left in UserDefaults from a prior run.
                await refresh(force: true)
                hasLoadedOnce = true
            }
        }
        // Onboarding dismissal fires this on first launch. `fullScreenCover`
        // can delay the underlying view's `.task` until the cover disappears,
        // so this guarantees the fresh-install fetch actually runs with the
        // view visible.
        .onReceive(NotificationCenter.default.publisher(for: .forceStoriesRefresh)) { _ in
            Task { await refresh(force: true) }
        }
    }

    // MARK: - Story List

    private var storyList: some View {
        List {
            if let lastUpdated = lastUpdatedText, !connectivity.isConnected || isStale {
                HStack(spacing: 6) {
                    if !connectivity.isConnected {
                        Image(systemName: "wifi.slash")
                            .font(.acimCaption2)
                    }
                    Text("Last updated \(lastUpdated)")
                        .font(.acimCaption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }

            ForEach(stories, id: \.storyHash) { story in
                let correction = corrections.first { $0.storyId == story.id }
                NavigationLink(value: story) {
                    StoryCard(story: story, sources: sources, correction: correction)
                }
                .contextMenu {
                    ShareLink(
                        item: ShareTextBuilder.shareText(
                            fact: story.fact,
                            sourceDisplay: story.sourceDisplay,
                            sources: sources
                        ),
                        preview: SharePreview("ACIM Daily Minute")
                    ) {
                        Label("Share Story", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        toggleBookmark(for: story)
                    } label: {
                        let isBookmarked = bookmarks.contains { $0.storyId == story.id }
                        Label(
                            isBookmarked ? "Remove Bookmark" : "Bookmark",
                            systemImage: isBookmarked ? "bookmark.slash" : "bookmark"
                        )
                    }
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .refreshable {
            if connectivity.isConnected {
                await refresh(force: true)
            } else {
                showOfflineToast = true
            }
        }
        .overlay(alignment: .top) {
            if showOfflineToast {
                Text("No internet connection")
                    .font(.acimCaption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { showOfflineToast = false }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showOfflineToast)
        .overlay(alignment: .top) {
            if watchTermMatchCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.acimCaption2)
                    Text("\(watchTermMatchCount) stor\(watchTermMatchCount == 1 ? "y matches" : "ies match") your watched terms")
                        .font(.acimCaption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    Task {
                        try? await Task.sleep(for: .seconds(4))
                        withAnimation { watchTermMatchCount = 0 }
                    }
                }
                .onTapGesture {
                    withAnimation { watchTermMatchCount = 0 }
                }
            }
        }
        .animation(.easeInOut, value: watchTermMatchCount)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading stories...")
                .font(.acimSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "newspaper")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Stories Available")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("Pull down to refresh")
                    .font(.acimSubheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .padding(.top, 100)
        }
        .refreshable {
            if connectivity.isConnected {
                await refresh(force: true)
            } else {
                showOfflineToast = true
            }
        }
        .overlay(alignment: .top) {
            if showOfflineToast {
                Text("No internet connection")
                    .font(.acimCaption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { showOfflineToast = false }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showOfflineToast)
    }

    // MARK: - Offline Empty

    private var offlineEmptyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Internet Connection")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("Pull down to refresh when connected")
                    .font(.acimSubheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .padding(.top, 100)
        }
        .refreshable {
            if connectivity.isConnected {
                await refresh(force: true)
            } else {
                showOfflineToast = true
            }
        }
        .overlay(alignment: .top) {
            if showOfflineToast {
                Text("No internet connection")
                    .font(.acimCaption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { showOfflineToast = false }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showOfflineToast)
    }

    // MARK: - Helpers

    private var lastUpdatedText: String? {
        let timestamp = UserDefaults.standard.double(forKey: FetchCooldownKey.stories)
        guard timestamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Stories are considered stale ~2× the server's 30-minute publish cadence.
    /// With a 15-minute in-session cooldown, anything older than ~20 minutes
    /// in the UI genuinely is stale — show the "Last updated …" header to
    /// signal that the user is looking at cached content.
    private var isStale: Bool {
        let timestamp = UserDefaults.standard.double(forKey: FetchCooldownKey.stories)
        guard timestamp > 0 else { return true }
        return Date().timeIntervalSince1970 - timestamp > 20 * 60
    }

    // MARK: - Bookmark Toggle

    private func toggleBookmark(for story: Story) {
        if let existing = bookmarks.first(where: { $0.storyId == story.id }) {
            modelContext.delete(existing)
        } else {
            let bookmark = Bookmark()
            bookmark.storyId = story.id
            bookmark.createdAt = Date()
            modelContext.insert(bookmark)
        }
    }

    // MARK: - Refresh

    /// Runs all three fetches **in parallel and independently**, then
    /// persists the results through `self.modelContext` on MainActor so
    /// `@Query` picks up the new rows immediately. Writing through a
    /// separate `ModelContext` (the previous shape) leaves the UI's query
    /// with a stale snapshot until the next re-evaluation — that's the
    /// bug that made fresh installs show a single story until the user
    /// pulled down to refresh.
    ///
    /// One endpoint failing must never hide another: per-task `do/catch`
    /// keeps stories, corrections, and sources independent.
    private func refresh(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        if force {
            FetchCooldown.reset(
                FetchCooldownKey.stories,
                FetchCooldownKey.corrections,
                FetchCooldownKey.sources
            )
        }

        let dataService = DataService(modelContainer: modelContext.container)
        let feedService = FeedService(modelContainer: modelContext.container)

        // Phase 1: pure network I/O off the MainActor. Three child tasks run
        // concurrently and return DTOs (or nil on error / cooldown skip).
        async let storiesResult: [StoryDTO]? = {
            do { return try await dataService.fetchStoryDTOs() }
            catch { print("[StoriesView] fetchStoryDTOs failed: \(String(reflecting: error))"); return nil }
        }()
        async let correctionsResult: [CorrectionDTO]? = {
            do { return try await dataService.fetchCorrectionDTOs() }
            catch { print("[StoriesView] fetchCorrectionDTOs failed: \(String(reflecting: error))"); return nil }
        }()
        async let sourcesResult: [SourceDTO]? = {
            do { return try await feedService.fetchSourceDTOs() }
            catch { print("[StoriesView] fetchSourceDTOs failed: \(String(reflecting: error))"); return nil }
        }()

        let storyDTOs = await storiesResult
        let correctionDTOs = await correctionsResult
        let sourceDTOs = await sourcesResult

        // Phase 2: persist through the SwiftUI-injected context so @Query
        // observes the writes immediately.
        if let storyDTOs {
            do { try DataService.persistStories(storyDTOs, in: modelContext) }
            catch { print("[StoriesView] persistStories failed: \(String(reflecting: error))") }
        }
        if let correctionDTOs {
            do { try DataService.persistCorrections(correctionDTOs, in: modelContext) }
            catch { print("[StoriesView] persistCorrections failed: \(String(reflecting: error))") }
        }
        if let sourceDTOs {
            do { try FeedService.persistSources(sourceDTOs, in: modelContext) }
            catch { print("[StoriesView] persistSources failed: \(String(reflecting: error))") }
        }

        let fetchedDTOs = storyDTOs ?? []

        // Foreground watch term check
        if UserDefaults.standard.bool(forKey: "notifyWatchedTerms"), !fetchedDTOs.isEmpty {
            let matches = WatchedTermMatcher.findNewMatches(in: fetchedDTOs)
            if !matches.isEmpty {
                withAnimation { watchTermMatchCount = matches.count }
                UserDefaults.standard.set(matches.count, forKey: "watchedTabBadge")
                await NotificationManager.shared.sendNotification(
                    title: "Watched Terms",
                    body: "\(matches.count) stor\(matches.count == 1 ? "y matches" : "ies match") your watched terms",
                    identifier: "watched-terms-\(Date().timeIntervalSince1970)",
                    userInfo: ["type": "watchedTerms"]
                )
                WatchedTermMatcher.markAllNotified(hashes: Set(fetchedDTOs.map(\.hash)))
            }
        }
    }
}

#Preview {
    StoriesView()
        .preferredColorScheme(.dark)
}
