import Foundation

#if os(iOS)
@preconcurrency import BackgroundTasks
import SwiftData

enum BackgroundRefreshManager {
    static let taskIdentifier = "com.larryseyer.acimdailyminute.refresh"

    /// Minimum gap between foreground catch-up runs. `BGAppRefreshTask` is
    /// opportunistic on iOS — on older devices it may never fire — so the
    /// foreground path is the *primary* notification trigger, not a fallback.
    /// We debounce to avoid hammering www.acimdailyminute.org during rapid app switches.
    private static let foregroundDebounceInterval: TimeInterval = 60
    private static let lastForegroundCheckKey = "lastForegroundCheck"

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleRefresh(task: refreshTask)
        }
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Foreground catch-up. Runs the same notification checks as the BGTask
    /// handler, but gated by a 60-second debounce so quick app-switches don't
    /// re-fetch. Call this from scenePhase transitions to `.active`.
    static func performForegroundCheck() {
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: lastForegroundCheckKey)
        guard now - last > foregroundDebounceInterval else { return }
        UserDefaults.standard.set(now, forKey: lastForegroundCheckKey)
        Task { await performBackgroundCheck() }
    }

    private static func handleRefresh(task: BGAppRefreshTask) {
        scheduleRefresh() // Reschedule for next time

        let taskRunner = Task {
            await performBackgroundCheck()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            taskRunner.cancel()
        }
    }

    /// Runs all enabled text-only notification checks. Deliberately excludes
    /// the daily digest: audio/video content drops once per day at 00:00 GMT
    /// and the user will see the new episode whenever they next open the
    /// Digest tab. Spending scarce `BGAppRefreshTask` budget on polling
    /// `podcast.xml` would steal runway from the breaking-news, corrections,
    /// and watched-term checks that actually warrant interrupting the user.
    private static func performBackgroundCheck() async {
        let notifyCorrections = UserDefaults.standard.bool(forKey: "notifyCorrections")
        let notifyBreaking = UserDefaults.standard.bool(forKey: "notifyBreakingFacts")
        let notifyWatchedTerms = UserDefaults.standard.bool(forKey: "notifyWatchedTerms")

        guard notifyCorrections || notifyBreaking || notifyWatchedTerms else { return }

        if notifyBreaking {
            await checkForBreakingFacts()
        }

        if notifyCorrections {
            await checkForCorrections()
        }

        if notifyWatchedTerms {
            await checkForWatchedTerms()
        }
    }

    private static func checkForBreakingFacts() async {
        do {
            let url = URL(string: "https://www.acimdailyminute.org/stories.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(StoriesResponse.self, from: data)

            let lastCheckKey = "lastBreakingCheck"
            let hasRunBefore = UserDefaults.standard.object(forKey: lastCheckKey) != nil
            let lastCheckDate = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: lastCheckKey))

            let newBreaking = response.stories.filter { story in
                guard let publishedStr = story.publishedAt else { return false }
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = formatter.date(from: publishedStr) ?? {
                    formatter.formatOptions = [.withInternetDateTime]
                    return formatter.date(from: publishedStr)
                }()
                guard let date else { return false }
                return date > lastCheckDate
            }

            // First ever run: seed the baseline silently so we don't spam the
            // user with "N new facts" on fresh install. Subsequent runs fire
            // for anything newer than the previous check — no artificial 1hr
            // window, which previously dropped valid stories whenever BGTask
            // happened to wake more than an hour after publication.
            if hasRunBefore, !newBreaking.isEmpty {
                await NotificationManager.shared.sendNotification(
                    title: "Breaking Facts",
                    body: "\(newBreaking.count) new verified fact\(newBreaking.count == 1 ? "" : "s") published",
                    identifier: "breaking-\(Date().timeIntervalSince1970)"
                )
                LiveActivityManager.startOrUpdate(
                    storyCount: newBreaking.count,
                    latestFact: newBreaking.first?.fact ?? "",
                    publishedDate: Date()
                )
            }

            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
        } catch {
            print("[BackgroundRefresh] checkForBreakingFacts failed: \(String(reflecting: error))")
        }
    }

    private static func checkForCorrections() async {
        do {
            let url = URL(string: "https://www.acimdailyminute.org/corrections.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(CorrectionsResponse.self, from: data)
            let corrections = response.corrections

            let lastCountKey = "lastCorrectionCount"
            // Distinguish "never checked" from "checked, count was zero" —
            // the previous `lastCount > 0` guard made the first non-zero
            // delta unreachable because UserDefaults.integer(forKey:) returns
            // 0 for both cases.
            let hasRunBefore = UserDefaults.standard.object(forKey: lastCountKey) != nil
            let lastCount = UserDefaults.standard.integer(forKey: lastCountKey)

            if hasRunBefore, corrections.count > lastCount {
                let newCount = corrections.count - lastCount
                await NotificationManager.shared.sendNotification(
                    title: "Corrections Posted",
                    body: "\(newCount) new correction\(newCount == 1 ? "" : "s") published",
                    identifier: "corrections-\(Date().timeIntervalSince1970)"
                )
            }

            UserDefaults.standard.set(corrections.count, forKey: lastCountKey)
        } catch {
            print("[BackgroundRefresh] checkForCorrections failed: \(String(reflecting: error))")
        }
    }

    private static func checkForWatchedTerms() async {
        guard !WatchedTermsStorage.terms.isEmpty else { return }

        do {
            let url = URL(string: "https://www.acimdailyminute.org/stories.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(StoriesResponse.self, from: data)

            let matches = WatchedTermMatcher.findNewMatches(in: response.stories)
            if !matches.isEmpty {
                UserDefaults.standard.set(matches.count, forKey: "watchedTabBadge")
                await NotificationManager.shared.sendNotification(
                    title: "Watched Terms",
                    body: "\(matches.count) new stor\(matches.count == 1 ? "y matches" : "ies match") your watched terms",
                    identifier: "watched-terms-\(Date().timeIntervalSince1970)",
                    userInfo: ["type": "watchedTerms"]
                )
            }

            WatchedTermMatcher.markAllNotified(hashes: Set(response.stories.map(\.hash)))
        } catch {
            print("[BackgroundRefresh] checkForWatchedTerms failed: \(String(reflecting: error))")
        }
    }

}
#endif
