import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var audioManager = AudioManager()
    @State private var connectivity = ConnectivityManager()
    @State private var selectedTab = 0
    @State private var showSettings = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    #if os(iOS) || os(tvOS)
    /// The real height of the tab bar the mini player has to clear.
    ///
    /// ⛔ **This used to be the literal `49`, and 49 is only ever right on an
    /// iPhone at an ordinary text size.** iOS 18 draws iPad a floating tab bar
    /// of a different height entirely, and on both platforms the bar grows with
    /// Dynamic Type. A mini player padded by a guess either floats above the bar
    /// with a gap under it or sits behind it, and neither is visible to any
    /// check that does not run on the device the guess is wrong for.
    /// `MiniPlayerView.height` is a different number for a different job — what
    /// the thirteen reading surfaces reserve so their last line is not covered —
    /// and the two must not be confused.
    @State private var tabBarHeight: CGFloat = 49
    #endif
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

    private func follow(_ route: DeepLinkRoute) {
        switch route {
        case .today:
            selectedTab = 0
        case .lessons:
            selectedTab = 1
        case .lesson(let n):
            selectedTab = 1
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .deepLinkLesson, object: n)
            }
        case .archive(let d):
            selectedTab = 3
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .deepLinkArchive, object: d)
            }
        case .saved:
            // ⛔ Tag 4 does not exist on the television, and selecting a tag no
            // tab carries leaves a `TabView` showing nothing at all. Today is
            // where a television goes instead — the route is reachable only
            // from a URL or a notification tap, and tvOS has neither.
            #if os(tvOS)
            selectedTab = 0
            #else
            selectedTab = 4
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
        #if os(iOS) || os(tvOS)
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tabItem { Label("Today", systemImage: "sun.max.fill") }
                    .tag(0)

                LessonsView()
                    .tabItem { Label("Read", systemImage: "book.closed.fill") }
                    .tag(1)

                ListenView()
                    .tabItem { Label("Listen", systemImage: "play.circle.fill") }
                    .tag(2)

                ArchiveView()
                    .tabItem { Label("Archive", systemImage: "archivebox.fill") }
                    .tag(3)

                // ⛔ **No Saved tab on the television, and it is not a fence
                // for tidiness.** With highlights, notes and saves all gone
                // from tvOS — his call — every one of this screen's three
                // lists falls to a `ContentUnavailableView` telling the reader
                // to do something the television cannot do. A tab that can
                // only ever be three apologies is not a tab.
                #if !os(tvOS)
                SavedView()
                    .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                    .tag(4)
                #endif
            }

            if audioManager.hasActiveAudio && selectedTab != 2 {
                MiniPlayerView()
                    .onTapGesture { selectedTab = 2 }
                    .padding(.bottom, tabBarHeight)
                    .transition(.move(edge: .bottom))
            }
        }
        .background(TabBarHeightReader { tabBarHeight = $0 })
        #else
        // macOS: skip SwiftUI's TabView (which renders a top segmented
        // control that looks nothing like iOS) and build the content +
        // bottom tab bar manually so the macOS app matches the iOS look.
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case 1: LessonsView()
                    case 2: ListenView()
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

    private static let accent = Color.acimGold

    private struct Item: Identifiable {
        let id: Int
        let title: String
        let systemImage: String
    }

    private let items: [Item] = [
        .init(id: 0, title: "Today", systemImage: "sun.max.fill"),
        .init(id: 1, title: "Read", systemImage: "book.closed.fill"),
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

#if os(iOS) || os(tvOS)
/// Reports the height of the tab bar the view it backs is sitting in.
///
/// ⛔ **There is no SwiftUI way to ask this, and the number cannot be assumed.**
/// A `TabView`'s bar is drawn inside the `TabView`'s own bounds, so the `ZStack`
/// overlaying the mini player sees only the screen's safe area, never the bar.
/// The bar's height is 49pt on an iPhone at an ordinary text size and something
/// else on an iPad under iOS 18's floating bar, at large Dynamic Type, or in a
/// Slide Over slice.
///
/// ⛔ **The mini player must NOT be moved into a `safeAreaInset` on the `TabView`
/// instead.** SwiftUI would propagate that inset into all thirteen surfaces that
/// already reserve `MiniPlayerView.height` for themselves, and each would then
/// add its own reservation on top of the propagated one — every one of the
/// thirteen would leave a double gap. Reading the bar and padding by it keeps
/// the reservation exactly where it already is.
///
/// It draws nothing. `UIViewRepresentable` is used the way the repo's other
/// three representables are not — as a probe rather than a content host — so it
/// reports through a closure and holds no state of its own.
private struct TabBarHeightReader: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        view.onChange = onChange
        view.report()
    }

    final class ProbeView: UIView {
        var onChange: ((CGFloat) -> Void)?
        private var last: CGFloat = 0

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        /// Walks the responder chain to the enclosing tab bar controller. The
        /// responder chain rather than `superview`: SwiftUI hosts this view
        /// several container views below the controller, and the chain crosses
        /// those without caring how many there are.
        func report() {
            var responder: UIResponder? = self
            while let current = responder {
                if let tabs = current as? UITabBarController {
                    let height = tabs.tabBar.frame.height
                    // A bar mid-transition measures zero. Reporting that would
                    // drop the mini player behind the bar for a frame.
                    if height > 0, abs(height - last) > 0.5 {
                        last = height
                        onChange?(height)
                    }
                    return
                }
                responder = current.next
            }
        }
    }
}
#endif

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
