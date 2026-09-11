import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ConnectivityManager.self) private var connectivity
    @Environment(AudioManager.self) private var audio
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \DailyMinute.publishedAt, order: .reverse) private var minutes: [DailyMinute]
    @Query(sort: \DailyLesson.publishedAt, order: .reverse) private var lessons: [DailyLesson]

    @State private var hasLoadedOnce = false
    @State private var isRefreshing = false
    @State private var showOfflineToast = false
    @State private var path = NavigationPath()
    @AppStorage("todayMotionDate") private var motionDate = ""
    @State private var ruleProgress: CGFloat = 1
    @State private var passageOpacity: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(tvOS)
    @Environment(\.openPlayer) private var openPlayer
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !connectivity.isConnected && (minutes.first != nil || lessons.first != nil) {
                        offlineBanner
                            .padding(.bottom, Metric.tight)
                    }

                    if minutes.isEmpty && lessons.isEmpty && corpusReading == nil {
                        emptyState
                    } else {
                        TodayMasthead(
                            date: Date(),
                            lessonNumber: workbookDay,
                            ruleProgress: ruleProgress
                        )
                    }

                    if let minute = minutes.first, !isMinuteStale {
                        #if os(tvOS)
                        Button { openPlayer(.minute(minute)) } label: {
                            DailyMinuteCard(minute: minute)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, Metric.block)
                        .opacity(passageOpacity)
                        #else
                        DailyMinuteCard(minute: minute)
                            .padding(.top, Metric.block)
                            .opacity(passageOpacity)
                        #endif
                    } else if let segment = corpusReading {
                        #if os(tvOS)
                        Button { openPlayer(.segment(segment)) } label: {
                            CorpusReadingCard(segment: segment)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, Metric.block)
                        .opacity(passageOpacity)
                        #else
                        CorpusReadingCard(segment: segment)
                            .padding(.top, Metric.block)
                            .opacity(passageOpacity)
                        #endif
                    }

                    if let lesson = lessons.first {
                        #if os(tvOS)
                        Button { openPlayer(.lesson(lesson)) } label: {
                            DailyLessonCard(lesson: lesson)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 26)
                        #else
                        DailyLessonCard(lesson: lesson)
                            .padding(.top, 26)
                        #endif
                    }

                    #if !os(tvOS)
                    PracticeCard()
                        .padding(.top, 14)
                    #endif
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .readableContentWidth()
            }
            .acimInkBackground()
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .readingDestinations(path: $path)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
            }
            #if !os(tvOS)
            .refreshable {
                if connectivity.isConnected {
                    await refresh(force: true)
                } else {
                    showOfflineToast = true
                }
            }
            #endif
            .onAppear { playOpeningIfNeeded() }
            .task {
                if !hasLoadedOnce {
                    await refresh(force: true)
                    hasLoadedOnce = true
                }
                playOpeningIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, hasLoadedOnce else { return }
                Task { await refresh(force: false) }
            }
            .onChange(of: connectivity.isConnected) { oldValue, newValue in
                guard !oldValue, newValue, hasLoadedOnce else { return }
                showOfflineToast = false
                Task { await refresh(force: true) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .forceMinuteRefresh)) { _ in
                Task { await refresh(force: true) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .forceLessonRefresh)) { _ in
                Task { await refresh(force: true) }
            }
        }
    }

    /// The feed is the authority; this is only the floor under it. Never
    /// persisted as a `DailyMinute` — a corpus reading would collide on the date
    /// key with the real one the feed eventually supplies for that day.
    private var isMinuteStale: Bool {
        CorpusFallback.isStale(newest: minutes.first?.publishedAt)
    }

    private var corpusReading: CorpusSegment? {
        guard isMinuteStale else { return nil }
        return CorpusFallback.segment(for: Date())
    }

    private var workbookDay: Int? {
        #if os(tvOS)
        lessons.first?.lessonNumber
        #else
        PracticeReminderService.currentLesson() ?? lessons.first?.lessonNumber
        #endif
    }

    private var todayStamp: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func playOpeningIfNeeded() {
        guard minutes.first != nil || corpusReading != nil else { return }
        guard motionDate != todayStamp else { return }
        motionDate = todayStamp
        guard !reduceMotion else { return }
        ruleProgress = 0
        passageOpacity = 0
        withAnimation(.easeInOut(duration: 0.4)) { ruleProgress = 1 }
        withAnimation(.easeInOut(duration: 0.3).delay(0.4)) { passageOpacity = 1 }
    }

    private var offlineBanner: some View {
        Label("Offline — showing last cached reading", systemImage: "wifi.slash")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing cached yet", systemImage: "sun.max")
        } description: {
            Text(connectivity.isConnected
                 ? "Pull to refresh to load today's passage and lesson."
                 : "Connect to the internet, then pull to refresh.")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    @MainActor
    private func refresh(force: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let service = DataService(modelContainer: modelContext.container)
        do {
            async let minuteDTO = service.fetchDailyMinute(force: force)
            async let lessonDTO = service.fetchDailyLesson(force: force)
            let (m, l) = try await (minuteDTO, lessonDTO)
            if let m { try DataService.persistMinute(m, in: modelContext) }
            if let l { try DataService.persistLesson(l, in: modelContext) }
        } catch {
            if !connectivity.isConnected {
                showOfflineToast = true
            }
        }
    }
}

#Preview {
    TodayView()
        .preferredColorScheme(.dark)
}
