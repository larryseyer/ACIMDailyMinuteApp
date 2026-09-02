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

    /// Runs every enabled check and tells the reader ONCE about whatever is new.
    ///
    /// ⛔ One notification per run, not one per channel. A new day publishes a
    /// minute and a lesson together, so three independent checks that each
    /// sent their own notification put "New Daily Minute", "Lesson 84" and a
    /// phrase match on the lock screen one after another, about one event. Each
    /// check now only answers what is new; the sending happens once, below.
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

        var news = News()
        if notifyMinute, let minute, newMinute(minute) {
            news.minute = minute
        }
        if notifyLesson, let lesson, newLesson(lesson) {
            news.lesson = lesson
        }
        if notifyPhrases {
            news.phraseMatches = newPhraseMatches(minute: minute, lesson: lesson)
        }

        guard let notification = news.notification else { return }
        await NotificationManager.shared.sendNotification(
            title: notification.title,
            body: notification.body,
            identifier: notification.identifier,
            userInfo: notification.userInfo
        )
        if !news.phraseMatches.isEmpty {
            PhraseMatcher.markAllNotified(itemKeys: news.phraseMatches.map(\.itemKey))
        }
    }

    /// What one run found, and the single notification it becomes.
    struct News {
        var minute: DailyMinuteResponse?
        var lesson: DailyLessonResponse?
        var phraseMatches: [PhraseMatcher.Match] = []

        struct Notification {
            let title: String
            let body: String
            let identifier: String
            let userInfo: [String: String]
        }

        /// Nil when nothing is new. A tap still opens the phrase editor when a
        /// phrase matched, whatever else the notification carries.
        var notification: Notification? {
            let matches = phraseMatches.count
            let matchLine = matches == 0 ? nil
                : "\(matches) new reading\(matches == 1 ? "" : "s") match\(matches == 1 ? "es" : "") your phrases"
            let userInfo = matches == 0 ? [:] : ["type": "phraseMatch"]

            switch (minute, lesson) {
            case (nil, nil):
                guard let matchLine else { return nil }
                return Notification(
                    title: "Phrase Match", body: matchLine,
                    identifier: "phrase-match-\(Date().timeIntervalSince1970)", userInfo: userInfo
                )
            case (let minute?, nil):
                return Notification(
                    title: "New Daily Minute",
                    body: [minute.text, matchLine].compactMap { $0 }.joined(separator: "\n"),
                    identifier: "minute-\(minute.segment_id)", userInfo: userInfo
                )
            case (nil, let lesson?):
                return Notification(
                    title: "Lesson \(lesson.lesson_id)",
                    body: [lesson.title, matchLine].compactMap { $0 }.joined(separator: "\n"),
                    identifier: "lesson-\(lesson.lesson_id)", userInfo: userInfo
                )
            case (let minute?, let lesson?):
                return Notification(
                    title: "Today's reading is ready",
                    body: ["A new Daily Minute and Lesson \(lesson.lesson_id): \(lesson.title)", matchLine]
                        .compactMap { $0 }.joined(separator: "\n"),
                    identifier: "reading-\(minute.segment_id)-\(lesson.lesson_id)", userInfo: userInfo
                )
            }
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

    /// Whether a fresh Daily Minute has been published since the previous run,
    /// comparing `(segment_id, date)`. The first-ever run seeds the baseline
    /// silently so a fresh install does not start with a "new" pop.
    private static func newMinute(_ dto: DailyMinuteResponse) -> Bool {
        let lastIdKey = "lastMinuteSegmentId"
        let lastDateKey = "lastMinuteDate"
        let hasRunBefore = UserDefaults.standard.object(forKey: lastIdKey) != nil
        let lastId = UserDefaults.standard.integer(forKey: lastIdKey)
        let lastDate = UserDefaults.standard.string(forKey: lastDateKey) ?? ""

        let isNew = dto.segment_id != lastId || dto.date != lastDate

        UserDefaults.standard.set(dto.segment_id, forKey: lastIdKey)
        UserDefaults.standard.set(dto.date, forKey: lastDateKey)
        return hasRunBefore && isNew
    }

    /// Whether a fresh Daily Lesson has been published since the previous run,
    /// comparing `lesson_id`.
    private static func newLesson(_ dto: DailyLessonResponse) -> Bool {
        let lastIdKey = "lastLessonId"
        let hasRunBefore = UserDefaults.standard.object(forKey: lastIdKey) != nil
        let lastId = UserDefaults.standard.integer(forKey: lastIdKey)

        UserDefaults.standard.set(dto.lesson_id, forKey: lastIdKey)
        return hasRunBefore && dto.lesson_id != lastId
    }

    /// The reader's phrase watchlist run against today's minute and lesson.
    /// `PhraseMatcher` handles dedup via `PhraseStorage.notifiedItemKeys`, so
    /// re-running on the same content finds nothing new. The caller marks the
    /// matches notified once the notification has gone.
    private static func newPhraseMatches(
        minute: DailyMinuteResponse?,
        lesson: DailyLessonResponse?
    ) -> [PhraseMatcher.Match] {
        guard !PhraseStorage.phrases.isEmpty else { return [] }

        var matches: [PhraseMatcher.Match] = []
        if let minute { matches.append(contentsOf: PhraseMatcher.findNewMatches(inMinute: minute)) }
        if let lesson { matches.append(contentsOf: PhraseMatcher.findNewMatches(inLesson: lesson)) }

        if !matches.isEmpty {
            UserDefaults.standard.set(matches.count, forKey: "phraseMatchBadge")
        }
        return matches
    }
}
#endif
