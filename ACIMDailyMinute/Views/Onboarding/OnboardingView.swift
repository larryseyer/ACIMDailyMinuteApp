import SwiftUI

#if os(tvOS)
/// A television lands focus on the first thing that will take it, and Skip
/// is always on screen. Without a preferred target, Select dismisses the
/// introduction rather than paging it. The chevron (or Continue, or Get
/// Started) is the thing a remote should be holding.
private enum OnboardingFocus: Hashable {
    case previous, next, skip, continuePage, getStarted
}
#endif

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    /// The companion note is the last thing the introduction says, and it is a
    /// stage rather than a sixth carousel page: it is a different kind of screen
    /// — a note from one student to another, set in serif and scrolled — and it
    /// reads as one. Living inside this view is what makes it reach both
    /// entrances for free, since `hasSeenOnboarding` is the only thing that
    /// presents the introduction and **Replay introduction** merely clears it.
    @State private var showingNote = false
    #if os(tvOS)
    @FocusState private var focused: OnboardingFocus?
    #endif

    private var pages: [(systemImage: String, title: String, description: String)] {
        [
            // His wording, verbatim.
            ("sun.max", "A Minute a Day",
             // Three lines, broken where he set them, so the title of the
             // book stands on its own line.
             "A short passage from\nA Course in Miracles,\ndelivered daily."),
            ("book.closed", "Today's Lesson",
             "The Workbook for Students\none lesson at a time,\non the day you choose."),
            ("play.circle", "Listen",
             "Every passage and lesson, read aloud.\nListen while you commute, walk, or sit still.\nDaily Minutes and Daily Lessons are added regularly."),
            ("archivebox", "Archive",
             "Browse past readings by date.\nReturn to any passage at your choosing.\nYour notes and highlights are stored across all devices."),
            ("bookmark", "Save Your Favorites",
             "Keep the passages you mark as favorites.\nReturn to them anytime, online or off.")
        ]
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if showingNote {
                noteStage
            } else {
                carousel
            }

            skipButton
        }
        // Forced dark for this subtree only. `preferredColorScheme` would
        // reach the window, and a scheme given to the window is not taken
        // back when the cover comes down — the reader's own choice is.
        .environment(\.colorScheme, .dark)
        #if os(tvOS)
        .onAppear { focused = .next }
        .onChange(of: currentPage) { _, page in
            focused = page == pages.count - 1 ? .continuePage : .next
        }
        .onChange(of: showingNote) { _, showing in
            if showing { focused = .getStarted }
        }
        #endif
        #if os(macOS)
        .background(QuittableSheet())
        #endif
    }

    /// The introduction can be left at any point, from either stage. On
    /// macOS, Escape already closes the sheet by writing `false` through the
    /// presentation binding in `ContentView`, so this button carries no
    /// `.cancelAction` shortcut: a sheet holding one answers a quit request
    /// as "cancelled", and Cmd-Q stops working for as long as it is up.
    private var skipButton: some View {
        Button("Skip") {
            hasSeenOnboarding = true
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        // On a television the ring is the only thing telling someone across
        // the room where they are. Do not disable it here.
        .focused($focused, equals: .skip)
        #else
        // A Mac sheet hands its first enabled control keyboard focus, and a
        // plain button draws a ring around itself when it has it.
        .focusEffectDisabled()
        #endif
        .font(.acimSubheadline)
        .foregroundStyle(.secondary)
        .padding(.top, 20)
        .padding(.trailing, 24)
    }

    // MARK: - The companion note, as the introduction's last word

    /// Renders `CompanionNoteBody` — the same view Settings > About pushes — so
    /// the wording exists once. Only the frame around it differs: a button here,
    /// a navigation title there.
    private var noteStage: some View {
        VStack(spacing: 0) {
            ScrollView {
                CompanionNoteBody()
            }

            Button {
                hasSeenOnboarding = true
            } label: {
                Text("Get Started")
                    .font(.acimHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.acimGold)
            #if os(tvOS)
            .focused($focused, equals: .getStarted)
            #endif
            .padding(.horizontal, 40)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    // MARK: - The carousel

    @ViewBuilder
    private var carousel: some View {
        #if os(iOS)
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPage(
                        systemImage: page.systemImage,
                        title: page.title,
                        description: page.description,
                        showButton: index == pages.count - 1
                    ) {
                        showingNote = true
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

        }
        #else
        // macOS has no page-style TabView in plain SwiftUI, so it draws one
        // page at a time with chevron buttons at the sides and dots at the
        // foot. tvOS takes the same treatment: a remote navigates between
        // things that hold focus, and a `TabView(.page)` moves only when a
        // page itself is focusable — which these cards are not. A button is.
        ZStack {
            VStack(spacing: 0) {
                let page = pages[currentPage]
                #if os(tvOS)
                OnboardingPage(
                    systemImage: page.systemImage,
                    title: page.title,
                    description: page.description,
                    showButton: currentPage == pages.count - 1,
                    focus: $focused
                ) {
                    showingNote = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(currentPage)
                .transition(.opacity)
                #else
                OnboardingPage(
                    systemImage: page.systemImage,
                    title: page.title,
                    description: page.description,
                    showButton: currentPage == pages.count - 1
                ) {
                    showingNote = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(currentPage)
                .transition(.opacity)
                #endif

                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage
                                  ? Color.acimGold
                                  : .gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 28)
            }

            HStack {
                pageChevron("chevron.left", isPrevious: true, enabled: currentPage > 0) {
                    currentPage -= 1
                }
                Spacer()
                pageChevron("chevron.right", isPrevious: false, enabled: currentPage < pages.count - 1) {
                    currentPage += 1
                }
            }
            .padding(.horizontal, 20)
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
        #endif
    }

    #if os(macOS) || os(tvOS)
    private func pageChevron(
        _ systemImage: String,
        isPrevious: Bool,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .frame(width: 56, height: 80)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .focused($focused, equals: isPrevious ? .previous : .next)
        #else
        // A Mac sheet hands its first enabled control keyboard focus; the
        // ring is noise around a button the pointer is already on. Space
        // still turns the page.
        .focusEffectDisabled()
        #endif
        .disabled(!enabled)
        .opacity(enabled ? 0.8 : 0.3)
    }
    #endif
}

// MARK: - Onboarding Page

private struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let description: String
    var showButton: Bool = false
    #if os(tvOS)
    var focus: FocusState<OnboardingFocus?>.Binding
    #endif
    var onContinue: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 72))
                .foregroundStyle(Color.acimGold)

            Text(title)
                .font(.acimTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.acimGold)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.acimBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if showButton {
                Button {
                    onContinue?()
                } label: {
                    // "Get Started" belongs to the note that follows, which is
                    // the actual last act. Saying it twice would promise the
                    // introduction was over a screen early.
                    Text("Continue")
                        .font(.acimHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.acimGold)
                #if os(tvOS)
                .focused(focus, equals: .continuePage)
                #endif
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
}
