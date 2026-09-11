import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var audioManager = AudioManager()
    @State private var connectivity = ConnectivityManager()
    @State private var selectedTab = 0
    @State private var coursePath = NavigationPath()
    @State private var showSettings = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    /// One player for Today and Video. Installing `openPlayer` on a single
    /// NavigationStack does not reach `navigationDestination` content on
    /// tvOS — a Video row then hits the default `assertionFailure`
    /// (crash ACIMDailyMinuteTV-2026-09-09-104129.ips). Read pushes a
    /// reading instead.
    @State private var playerItem: TVPlayerItem?
    #if os(iOS) || os(macOS)
    @State private var showNowPlaying = false
    #endif
    #if os(macOS)
    @State private var showAbout = false
    #endif

    var body: some View {
        tabContainer
            .environment(audioManager)
            .environment(connectivity)
            .environment(\.openPlayer, OpenPlayerAction { presentPlayer($0) })
            #if os(iOS) || os(macOS)
            .environment(\.openNowPlaying, OpenNowPlayingAction { showNowPlaying = true })
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
                    .environment(audioManager)
                    #if os(iOS)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    #endif
                    #if os(macOS)
                    .background(QuittableSheet())
                    .frame(minWidth: 420, minHeight: 680)
                    #endif
            }
            .onChange(of: audioManager.hasActiveAudio) { _, active in
                if !active { showNowPlaying = false }
            }
            #endif
            #if os(iOS) || os(tvOS)
            .fullScreenCover(item: $playerItem) { item in
                // The cover is a new presentation. On tvOS it does not
                // inherit @Environment(AudioManager.self) from the tabs —
                // nested under Jump to Lesson it assertionFailure'd
                // (ACIMDailyMinuteTV-2026-09-09-105807.ips). Hand it over.
                TVPlayerView(item: item)
                    .environment(audioManager)
            }
            #else
            .sheet(item: $playerItem) { item in
                TVPlayerView(item: item)
                    .environment(audioManager)
            }
            #endif
            .task { await warmPodcastCache() }
            .animation(.easeInOut(duration: 0.2), value: audioManager.hasActiveAudio)
            .onAppear {
                connectivity.start()
                applyScreenshotTabIfRequested()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    audioManager.persistProgress()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
                showSettings = true
            }
            // A reminder tap lands where a URL would, through the same switch,
            // so a notification can never open somewhere a link cannot.
            .onReceive(NotificationCenter.default.publisher(for: .reminderTapped)) { note in
                guard let route = note.object as? DeepLinkRoute else { return }
                follow(route)
            }
            .onOpenURL { url in
                guard let route = DeepLinkRoute.parse(url) else { return }
                follow(route)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            #if os(iOS) || os(tvOS)
            .fullScreenCover(isPresented: introductionPresented) {
                OnboardingView()
            }
            #else
            .sheet(isPresented: introductionPresented) {
                OnboardingView()
            }
            #endif
            #if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: .openAboutRequested)) { _ in
                showAbout = true
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            #endif
    }

    /// Attach a published MP3 before the cover appears. Updating the item
    /// afterwards would not rebuild `fullScreenCover` — identity is the
    /// lesson id, and that does not change when the URL arrives.
    private func presentPlayer(_ item: TVPlayerItem) {
        if let url = item.audioURL, !url.isEmpty {
            playerItem = item
            return
        }
        guard let number = LessonNarration.number(fromPlayerID: item.id) else {
            playerItem = item
            return
        }
        let attached = attaching(item, number: number)
        if attached.audioURL != nil {
            playerItem = attached
            return
        }
        Task {
            await warmPodcastCache()
            playerItem = attaching(item, number: number)
        }
    }

    private func attaching(_ item: TVPlayerItem, number: Int) -> TVPlayerItem {
        let daily: String? = {
            let descriptor = FetchDescriptor<DailyLesson>(
                predicate: #Predicate { $0.lessonNumber == number }
            )
            return (try? modelContext.fetch(descriptor))?.first?.audioURL
        }()
        let archived: String? = {
            let channel = "daily-lesson"
            let descriptor = FetchDescriptor<ArchivedReading>(
                predicate: #Predicate { $0.channel == channel && $0.lessonNumber == number }
            )
            return (try? modelContext.fetch(descriptor))?.first?.audioURL
        }()
        let podcasts = (try? modelContext.fetch(
            FetchDescriptor<CachedPodcastEpisode>(
                predicate: #Predicate { $0.channel == "lesson" }
            )
        )) ?? []
        let podcast = LessonNarration.podcastURL(
            forLesson: number,
            episodes: podcasts.map { (id: $0.id, title: $0.title, audioURL: $0.audioURL) }
        )
        guard let url = LessonNarration.url(daily: daily, archived: archived, podcast: podcast) else {
            return item
        }
        return item.withAudioURL(url)
    }

    private func warmPodcastCache() async {
        let service = PodcastService()
        if let lessons = try? await service.fetchLessonEpisodes(force: false) {
            try? PodcastService.persist(lessons, channel: "lesson", in: modelContext)
        }
        if let minutes = try? await service.fetchMinuteEpisodes(force: false) {
            try? PodcastService.persist(minutes, channel: "minute", in: modelContext)
        }
    }

    /// Debug-only: `defaults write … ACIM_SCREENSHOT_TAB read` (or listen,
    /// video, saved, lesson, settings) opens that surface without going
    /// through a system "Open in app?" alert. The env var
    /// `ACIM_SCREENSHOT_TAB` still works. Release builds ignore this.
    private func applyScreenshotTabIfRequested() {
        #if DEBUG
        let tab = ProcessInfo.processInfo.environment["ACIM_SCREENSHOT_TAB"]
            ?? UserDefaults.standard.string(forKey: "ACIM_SCREENSHOT_TAB")
        UserDefaults.standard.removeObject(forKey: "ACIM_SCREENSHOT_TAB")
        switch tab {
        case "read", "listen":
            selectedTab = 1
            coursePath = NavigationPath()
            coursePath.append(CourseShelf.lesson)
        case "video", "archive":
            selectedTab = 1
            coursePath = NavigationPath()
            coursePath.append(CourseShelf.minute)
            if let day = LessonSchedule.day(from: "2026-09-02") {
                coursePath.append(MinuteDateRef(dateString: MinuteSchedule.utcDateString(from: day)))
            }
        case "saved":
            #if os(tvOS)
            selectedTab = 0
            #else
            selectedTab = 2
            #endif
        case "lesson":
            selectedTab = 1
            coursePath = NavigationPath()
            coursePath.append(CourseShelf.lesson)
            // Unpublished: bundled text, no YouTube. A recorded lesson
            // auto-presents video and the store shot becomes the overlay.
            coursePath.append(256)
        case "settings":
            showSettings = true
        default:
            break
        }
        #endif
    }

    private func follow(_ route: DeepLinkRoute) {
        switch route {
        case .today:
            selectedTab = 0
        case .lessons:
            selectedTab = 1
            coursePath = NavigationPath()
            coursePath.append(CourseShelf.lesson)
        case .listen:
            selectedTab = 1
            coursePath = NavigationPath()
            coursePath.append(CourseShelf.lesson)
        case .lesson(let n):
            selectedTab = 1
            coursePath = NavigationPath()
            coursePath.append(CourseShelf.lesson)
            coursePath.append(n)
        case .archive(let d):
            selectedTab = 1
            coursePath = NavigationPath()
            coursePath.append(CourseShelf.minute)
            coursePath.append(MinuteDateRef(dateString: MinuteSchedule.utcDateString(from: d)))
        case .saved:
            // Tag 2 does not exist on the television. Selecting a tag no
            // tab carries leaves a TabView showing nothing at all.
            #if os(tvOS)
            selectedTab = 0
            #else
            selectedTab = 2
            #endif
        }
    }

    /// Escape closes a macOS sheet by writing `false` through this binding.
    /// A setter that discarded the value left the introduction with no way
    /// out but its last page, so the write is honoured: leaving the
    /// introduction is the same as having seen it. The iOS cover has no
    /// interactive dismissal, so there the setter is never reached; **Skip**
    /// and **Get Started** write the flag themselves on both platforms.
    private var introductionPresented: Binding<Bool> {
        Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )
    }

    // MARK: - Tab container

    @ViewBuilder
    private var tabContainer: some View {
        #if os(tvOS)
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(0)
            CourseView(path: $coursePath)
                .tabItem { Label("Course", systemImage: "book.closed.fill") }
                .tag(1)
        }
        #elseif os(iOS)
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tabItem { Label("Today", systemImage: "sun.max.fill") }
                    .tag(0)
                    .toolbar(.hidden, for: .tabBar)
                CourseView(path: $coursePath)
                    .tabItem { Label("Course", systemImage: "book.closed.fill") }
                    .tag(1)
                    .toolbar(.hidden, for: .tabBar)
                SavedView()
                    .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                    .tag(2)
                    .toolbar(.hidden, for: .tabBar)
            }

            floatingChrome
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: ACIMTabBar.clearance)
        }
        #else
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 1: CourseView(path: $coursePath)
                case 2: SavedView()
                default: TodayView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            floatingChrome
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: ACIMTabBar.clearance)
        }
        #endif
    }

    #if os(iOS) || os(macOS)
    /// Tab bar plus, when audio is active, the compact Now Playing bar 8pt
    /// above it. The television has neither: the composed player is full
    /// screen, and a mini player on the tabs is a focus trap.
    private var floatingChrome: some View {
        VStack(spacing: 8) {
            if audioManager.hasActiveAudio && !showNowPlaying {
                MiniPlayerView()
                    .transition(.move(edge: .bottom))
            }
            ACIMTabBar(selectedTab: $selectedTab)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
    #endif
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
