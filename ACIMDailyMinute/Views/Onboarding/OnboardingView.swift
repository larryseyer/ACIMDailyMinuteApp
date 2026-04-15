import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private var pages: [(systemImage: String, title: String, description: String)] {
        [
            ("sun.max", "A Minute a Day",
             "A short passage from A Course in Miracles, delivered every day. Nothing added, nothing taken away."),
            ("book.closed", "Today's Lesson",
             "The Workbook for Students, one lesson at a time, on the day you're meant to read it."),
            ("play.circle", "Listen",
             "Every passage and lesson, read aloud. Listen while you commute, walk, or sit still."),
            ("archivebox", "Archive",
             "Browse past readings by date. Return to any passage when it calls you back."),
            ("bookmark", "Save Your Favorites",
             "Keep the passages that speak to you. Return to them anytime, online or off.")
        ]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
                            hasSeenOnboarding = true
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Text("Sparkly Edition · Teddy Poppe · CIMS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
            #else
            // macOS: no page-style TabView exists in plain SwiftUI, so
            // render one page at a time with a dot indicator and a
            // discreet chevron nav that matches the iOS visual language.
            VStack(spacing: 0) {
                let page = pages[currentPage]
                OnboardingPage(
                    systemImage: page.systemImage,
                    title: page.title,
                    description: page.description,
                    showButton: currentPage == pages.count - 1
                ) {
                    hasSeenOnboarding = true
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(currentPage)
                .transition(.opacity)

                Text("Sparkly Edition · Teddy Poppe · CIMS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                HStack(spacing: 16) {
                    Button {
                        withAnimation { currentPage -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPage == 0)
                    .opacity(currentPage == 0 ? 0.3 : 0.8)

                    HStack(spacing: 10) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage
                                      ? Color(red: 0.83, green: 0.69, blue: 0.22)
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
                    .disabled(currentPage == pages.count - 1)
                    .opacity(currentPage == pages.count - 1 ? 0.3 : 0.8)
                }
                .padding(.bottom, 28)
            }
            .animation(.easeInOut(duration: 0.25), value: currentPage)
            #endif
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Onboarding Page

private struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let description: String
    var showButton: Bool = false
    var onGetStarted: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 72))
                .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.22)) // #d4af37

            Text(title)
                .font(.acimTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.22))
                .multilineTextAlignment(.center)

            Text(description)
                .font(.acimBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if showButton {
                Button {
                    onGetStarted?()
                } label: {
                    Text("Get Started")
                        .font(.acimHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.83, green: 0.69, blue: 0.22))
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
