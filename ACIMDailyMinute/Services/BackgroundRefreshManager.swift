import Foundation

#if os(iOS)
@preconcurrency import BackgroundTasks

/// Keeps the practice reminders pointed at the right lesson while the app is
/// closed.
///
/// The practice reminders are laid out a few days ahead and name the lesson
/// they belong to, so they go stale when the publisher moves on to the next
/// one. This asks `daily-lesson.json` which lesson is current, records the
/// answer where `PracticeReminderService` reads it, and the reminders are laid
/// out again from there. Two channels drive it: `BGAppRefreshTask`, which iOS
/// grants when it likes and on an older phone may never grant, and a
/// 60-second-debounced check every time the app comes to the foreground, which
/// is therefore the primary trigger rather than a fallback.
enum BackgroundRefreshManager {
    static let taskIdentifier = "com.larryseyer.acimdailyminute.refresh"

    /// Minimum gap between foreground catch-up runs, so a rapid app switch
    /// does not hammer acimdailyminute.org.
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

    /// Foreground catch-up. Call this from scenePhase transitions to `.active`.
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

    /// Learns the newest published lesson, records it, and lays the practice
    /// reminders out again from it. Nothing is fetched when the practice
    /// reminders are off: there is nothing to keep current.
    private static func performBackgroundCheck() async {
        guard UserDefaults.standard.bool(forKey: PracticeAnchorStore.remindersEnabledKey) else { return }
        guard let lesson = await fetchLessonDTO() else { return }
        PracticeAnchorStore.record(lesson: lesson.lesson_id, day: lesson.date)
        await MainActor.run { PracticeReminderService.reschedule(in: nil) }
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
}
#endif
