import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private var pages: [(systemImage: String, title: String, description: String)] {
        [
            ("checkmark.shield", "Facts Without Opinion",
             "No tracking. No ads. No accounts. Just verified facts from independent sources."),
            ("newspaper", "Verified Stories",
             "Every fact checked against two independent sources with different owners. Source ratings and ownership on every card."),
            ("play.circle", "Daily Digest",
             "Watch or listen to the daily news digest. Video and audio, your choice."),
            ("archivebox", "Full Archive",
             "Browse by date or search across every fact ever published."),
            ("eye", "Watch What Matters",
             "Track stories by keyword. Get notified when matching facts are published.")
        ]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            #if os(iOS)
            // iOS: native paged swipe.
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
