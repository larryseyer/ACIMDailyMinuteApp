import SwiftUI

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
             "Every passage and lesson, read aloud. Listen while you commute, walk, or sit still. Daily Minutes and Daily Lessons are added regularly."),
            ("archivebox", "Archive",
             "Browse past readings by date. Return to any passage at your choosing. Your notes and highlights are stored across all devices."),
            ("bookmark", "Save Your Favorites",
             "Keep the passages you mark as favorites. Return to them anytime, online or off.")
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
        .focusEffectDisabled()
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
        // macOS: no page-style TabView exists in plain SwiftUI, so
        // render one page at a time with a dot indicator and a
        // discreet chevron nav that matches the iOS visual language.
        // A sheet hands its first enabled control keyboard focus, and a plain
        // button draws a ring around itself when it has it, so the ring is
        // switched off on both chevrons; Space still turns the page.
        VStack(spacing: 0) {
            let page = pages[currentPage]
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

            HStack(spacing: 16) {
                Button {
                    withAnimation { currentPage -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .disabled(currentPage == 0)
                .opacity(currentPage == 0 ? 0.3 : 0.8)

                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage
                                  ? Color.acimGold
                                  : .gray.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 8)

                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .disabled(currentPage == pages.count - 1)
                .opacity(currentPage == pages.count - 1 ? 0.3 : 0.8)
            }
            .padding(.bottom, 28)
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
        #endif
    }
}

// MARK: - Onboarding Page

private struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let description: String
    var showButton: Bool = false
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
