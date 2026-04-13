import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var audioManager = AudioManager()
    @State private var connectivity = ConnectivityManager()
    @State private var selectedTab = 0
    @State private var showSettings = false
    #if os(macOS)
    @State private var showAbout = false
    #endif
    @AppStorage("watchedTabBadge") private var watchedBadge = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        tabContainer
            .environment(audioManager)
            .environment(connectivity)
            .animation(.easeInOut(duration: 0.2), value: audioManager.hasActiveAudio)
            .onAppear { connectivity.start() }
            .task {
                ArchiveService.cleanupLegacySearchIndex()
                await ArchiveService(modelContainer: modelContext.container).prefetchAll()
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchedTermsTapped)) { _ in
                selectedTab = 4
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
                showSettings = true
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .modifier(OnboardingPresenter(hasSeenOnboarding: $hasSeenOnboarding))
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            #if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: .openAboutRequested)) { _ in
                showAbout = true
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            #endif
            .onChange(of: hasSeenOnboarding) { _, newValue in
                // Guarantee a fresh stories fetch once onboarding dismisses —
                // the underlying StoriesView's `.task` can be deferred by
                // `fullScreenCover` on first launch, and that's why a brand-new
                // install previously showed a single story until manual refresh.
                if newValue {
                    NotificationCenter.default.post(name: .forceStoriesRefresh, object: nil)
                }
            }
    }

    // MARK: - Tab container

    @ViewBuilder
    private var tabContainer: some View {
        #if os(iOS)
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                StoriesView()
                    .tabItem { Label("Stories", systemImage: "newspaper") }
                    .tag(0)

                DigestView()
                    .tabItem { Label("Digest", systemImage: "play.circle") }
                    .tag(1)

                ArchiveView()
                    .tabItem { Label("Archive", systemImage: "archivebox") }
                    .tag(2)

                SavedView()
                    .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                    .tag(3)

                WatchedView()
                    .tabItem { Label("Watched", systemImage: "eye.fill") }
                    .tag(4)
                    .badge(watchedBadge > 0 ? watchedBadge : 0)
            }

            if audioManager.hasActiveAudio && selectedTab != 1 {
                MiniPlayerView()
                    .onTapGesture { selectedTab = 1 }
                    .padding(.bottom, 49) // tab bar height
                    .transition(.move(edge: .bottom))
            }
        }
        #else
        // macOS: skip SwiftUI's TabView (which renders a top segmented
        // control that looks nothing like iOS) and build the content +
        // bottom tab bar manually so the macOS app matches the iOS look.
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case 1: DigestView()
                    case 2: ArchiveView()
                    case 3: SavedView()
                    case 4: WatchedView()
                    default: StoriesView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if audioManager.hasActiveAudio && selectedTab != 1 {
                    MiniPlayerView()
                        .onTapGesture { selectedTab = 1 }
                        .transition(.move(edge: .bottom))
                }
            }

            MacBottomTabBar(selectedTab: $selectedTab, watchedBadge: watchedBadge)
        }
        #endif
    }

    // MARK: - Deep Links

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "acimdailyminute" else { return }

        switch url.host {
        case "stories":
            selectedTab = 0
        case "story":
            let storyId = url.lastPathComponent
            let watchedTerms = WatchedTermsStorage.terms
            let context = ModelContext(modelContext.container)
            let descriptor = FetchDescriptor<Story>(
                predicate: #Predicate { $0.id == storyId }
            )
            if let story = try? context.fetch(descriptor).first {
                let matchesWatched = watchedTerms.contains { term in
                    story.fact.localizedCaseInsensitiveContains(term)
                }
                selectedTab = matchesWatched ? 4 : 0
            } else {
                selectedTab = 0
            }
        default:
            selectedTab = 0
        }
    }
}

/// Onboarding uses `fullScreenCover` on iOS (immersive) and `.sheet` on
/// macOS — `fullScreenCover` is iOS-only, and a windowed sheet is the
/// closest macOS equivalent for a first-launch takeover.
private struct OnboardingPresenter: ViewModifier {
    @Binding var hasSeenOnboarding: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
        }
        #else
        content.sheet(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
                .frame(width: 500, height: 600)
        }
        #endif
    }
}

#if os(macOS)
/// iOS-style bottom tab bar for macOS. SwiftUI's native `TabView` on
/// macOS renders a top segmented control; this component replaces it
/// so the macOS app matches the iOS layout: icons above labels, gold
/// tint for the selected tab, 49pt-ish bar height, subtle top divider.
private struct MacBottomTabBar: View {
    @Binding var selectedTab: Int
    let watchedBadge: Int

    private static let accent = Color(red: 0.83, green: 0.69, blue: 0.22)

    private struct Item: Identifiable {
        let id: Int
        let title: String
        let systemImage: String
    }

    private let items: [Item] = [
        .init(id: 0, title: "Stories", systemImage: "newspaper"),
        .init(id: 1, title: "Digest", systemImage: "play.circle"),
        .init(id: 2, title: "Archive", systemImage: "archivebox"),
        .init(id: 3, title: "Saved", systemImage: "bookmark.fill"),
        .init(id: 4, title: "Watched", systemImage: "eye.fill")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4)

            HStack(spacing: 0) {
                ForEach(items) { item in
                    tabButton(item)
                }
            }
            .padding(.vertical, 6)
            .background(.regularMaterial)
        }
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = selectedTab == item.id
        let showBadge = item.id == 4 && watchedBadge > 0

        return Button {
            selectedTab = item.id
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 22, weight: .regular))
                        .frame(height: 26)

                    if showBadge {
                        Text("\(watchedBadge)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red, in: Capsule())
                            .offset(x: 10, y: -4)
                    }
                }

                Text(item.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isSelected ? Self.accent : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
#endif

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
