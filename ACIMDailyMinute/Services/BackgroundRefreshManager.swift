import Foundation

#if os(iOS)
@preconcurrency import BackgroundTasks
import SwiftData

/// Coordinates BGTaskScheduler-driven and foreground catch-up notification
/// checks using a two-channel design (BGTask primary + foreground debounce
/// fallback). Watches for newly published Daily Minute segments, newly
/// published Daily Lessons, and user-defined phrase matches against either.
enum BackgroundRefreshManager {
    static let taskIdentifier = "com.larryseyer.acimdailyminute.refresh"

    /// Minimum gap between foreground catch-up runs. `BGAppRefreshTask` is
    /// opportunistic on iOS — on older devices it may never fire — so the
    /// foreground path is the *primary* notification trigger, not a fallback.
    /// We debounce to avoid hammering acimdailyminute.org during rapid app
    /// switches.
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
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
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
        scheduleRefresh()

        let taskRunner = Task {
            await performBackgroundCheck()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            taskRunner.cancel()
        }
    }

    /// Runs all enabled text-only notification checks. Each check is gated
    /// independently so the user's notification toggles in Settings map
    /// directly to a network call (or its absence).
    private static func performBackgroundCheck() async {
        let notifyMinute = UserDefaults.standard.bool(forKey: "notifyNewMinute")
        let notifyLesson = UserDefaults.standard.bool(forKey: "notifyNewLesson")
        let notifyPhrases = UserDefaults.standard.bool(forKey: "notifyPhraseMatches")

        guard notifyMinute || notifyLesson || notifyPhrases else { return }

        // Fetch once, share across all enabled checks. The phrase matcher
        // needs both DTOs anyway, so coalescing here halves background
        // bandwidth versus fetching each channel separately per check.
        async let minuteDTO = fetchMinuteDTO()
        async let lessonDTO = fetchLessonDTO()
        let (minute, lesson) = await (minuteDTO, lessonDTO)

        if notifyMinute, let minute {
            await checkForNewMinute(minute)
        }
        if notifyLesson, let lesson {
            await checkForNewLesson(lesson)
        }
        if notifyPhrases {
            await checkForPhraseMatches(minute: minute, lesson: lesson)
        }
    }

    // MARK: - Pure fetches

    private static func fetchMinuteDTO() async -> DailyMinuteResponse? {
        do {
            let url = URL(string: "https://www.acimdailyminute.org/daily-minute.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(DailyMinuteResponse.self, from: data)
        } catch {
            print("[BackgroundRefresh] fetchMinuteDTO failed: \(String(reflecting: error))")
            return nil
        }
    }

    private static func fetchLessonDTO() async -> DailyLessonResponse? {
        do {
            let url = URL(string: "https://www.acimdailyminute.org/daily-lesson.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(DailyLessonResponse.self, from: data)
        } catch {
            print("[BackgroundRefresh] fetchLessonDTO failed: \(String(reflecting: error))")
            return nil
        }
    }

    // MARK: - Per-channel checks

    /// Detects a freshly published Daily Minute by comparing
    /// `(segment_id, date)` against the values seen on the previous run.
    /// First-ever run seeds the baseline silently to avoid a "1 new" pop on
    /// fresh install.
    private static func checkForNewMinute(_ dto: DailyMinuteResponse) async {
        let lastIdKey = "lastMinuteSegmentId"
        let lastDateKey = "lastMinuteDate"
        let hasRunBefore = UserDefaults.standard.object(forKey: lastIdKey) != nil
        let lastId = UserDefaults.standard.integer(forKey: lastIdKey)
        let lastDate = UserDefaults.standard.string(forKey: lastDateKey) ?? ""

        let isNew = dto.segment_id != lastId || dto.date != lastDate

        if hasRunBefore, isNew {
            await NotificationManager.shared.sendNotification(
                title: "New Daily Minute",
                body: dto.text,
                identifier: "minute-\(dto.segment_id)"
            )
        }

        UserDefaults.standard.set(dto.segment_id, forKey: lastIdKey)
        UserDefaults.standard.set(dto.date, forKey: lastDateKey)
    }

    /// Detects a freshly published Daily Lesson by comparing `lesson_id`
    /// against the value seen on the previous run.
    private static func checkForNewLesson(_ dto: DailyLessonResponse) async {
        let lastIdKey = "lastLessonId"
        let hasRunBefore = UserDefaults.standard.object(forKey: lastIdKey) != nil
        let lastId = UserDefaults.standard.integer(forKey: lastIdKey)

        if hasRunBefore, dto.lesson_id != lastId {
            await NotificationManager.shared.sendNotification(
                title: "Lesson \(dto.lesson_id)",
                body: dto.title,
                identifier: "lesson-\(dto.lesson_id)"
            )
        }

        UserDefaults.standard.set(dto.lesson_id, forKey: lastIdKey)
    }

    /// Runs the user's phrase watchlist against today's minute and lesson.
    /// `PhraseMatcher` handles dedup via `PhraseStorage.notifiedItemKeys` so
    /// re-running on the same content is idempotent.
    private static func checkForPhraseMatches(
        minute: DailyMinuteResponse?,
        lesson: DailyLessonResponse?
    ) async {
        guard !PhraseStorage.phrases.isEmpty else { return }

        var matches: [PhraseMatcher.Match] = []
        if let minute { matches.append(contentsOf: PhraseMatcher.findNewMatches(inMinute: minute)) }
        if let lesson { matches.append(contentsOf: PhraseMatcher.findNewMatches(inLesson: lesson)) }

        guard !matches.isEmpty else { return }

        UserDefaults.standard.set(matches.count, forKey: "phraseMatchBadge")
        await NotificationManager.shared.sendNotification(
            title: "Phrase Match",
            body: "\(matches.count) new reading\(matches.count == 1 ? "" : "s") match\(matches.count == 1 ? "es" : "") your phrases",
            identifier: "phrase-match-\(Date().timeIntervalSince1970)",
            userInfo: ["type": "phraseMatch"]
        )

        PhraseMatcher.markAllNotified(itemKeys: matches.map(\.itemKey))
    }
}
#endif
