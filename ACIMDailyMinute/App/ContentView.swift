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

    var body: some View {
        tabContainer
            .environment(audioManager)
            .environment(connectivity)
            .animation(.easeInOut(duration: 0.2), value: audioManager.hasActiveAudio)
            .onAppear { connectivity.start() }
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
                showSettings = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .phrasesTapped)) { _ in
                // Phrases editor lives in Settings as of Phase 2 plan §8;
                // route notification taps to the Settings sheet until 3.8
                // wires the editor in-place.
                showSettings = true
            }
            .onOpenURL { _ in
                // Deep-link routing reactivates in Phase 3.8 alongside the
                // onboarding + bookmark features. Scheme registration stays
                // intact via Info.plist.
            }
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
    }

    // MARK: - Tab container

    @ViewBuilder
    private var tabContainer: some View {
        #if os(iOS)
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tabItem { Label("Today", systemImage: "sun.max.fill") }
                    .tag(0)

                LessonsPlaceholderView()
                    .tabItem { Label("Lessons", systemImage: "book.closed.fill") }
                    .tag(1)

                DigestView()
                    .tabItem { Label("Listen", systemImage: "play.circle.fill") }
                    .tag(2)

                ArchiveView()
                    .tabItem { Label("Archive", systemImage: "archivebox.fill") }
                    .tag(3)

                SavedView()
                    .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                    .tag(4)
            }

            if audioManager.hasActiveAudio && selectedTab != 2 {
                MiniPlayerView()
                    .onTapGesture { selectedTab = 2 }
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
                    case 1: LessonsPlaceholderView()
                    case 2: DigestView()
                    case 3: ArchiveView()
                    case 4: SavedView()
                    default: TodayView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if audioManager.hasActiveAudio && selectedTab != 2 {
                    MiniPlayerView()
                        .onTapGesture { selectedTab = 2 }
                        .transition(.move(edge: .bottom))
                }
            }

            MacBottomTabBar(selectedTab: $selectedTab)
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

    private static let accent = Color(red: 0.83, green: 0.69, blue: 0.22)

    private struct Item: Identifiable {
        let id: Int
        let title: String
        let systemImage: String
    }

    private let items: [Item] = [
        .init(id: 0, title: "Today", systemImage: "sun.max.fill"),
        .init(id: 1, title: "Lessons", systemImage: "book.closed.fill"),
        .init(id: 2, title: "Listen", systemImage: "play.circle.fill"),
        .init(id: 3, title: "Archive", systemImage: "archivebox.fill"),
        .init(id: 4, title: "Saved", systemImage: "bookmark.fill")
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

        return Button {
            selectedTab = item.id
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 22, weight: .regular))
                    .frame(height: 26)

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
