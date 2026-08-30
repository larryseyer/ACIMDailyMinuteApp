import Foundation

#if os(iOS)
import ActivityKit

enum LiveActivityManager {
    private static let dismissInterval: TimeInterval = 5 * 60

    static func startOrUpdate(
        channel: String,
        latestText: String,
        publishedDate: Date,
        lessonNumber: Int? = nil
    ) {
        guard UserDefaults.standard.bool(forKey: "notifyLiveActivities") else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = ACIMDailyMinuteAttributes.ContentState(
            // Same reason as the widget: a Live Activity is not a reading
            // surface and never passes through `ReadingText.displayString`.
            minuteText: PunctuationSpacing.repaired(latestText),
            lessonNumber: lessonNumber,
            publishedAt: publishedDate
        )

        // The Activity handle and its content are looked up inside the main-actor
        // task: handing a handle captured out here to ActivityKit's nonisolated
        // `update` would send a main-actor-isolated value across the boundary,
        // which Swift 6 rejects.
        if !Activity<ACIMDailyMinuteAttributes>.activities.isEmpty {
            Task { @MainActor in
                guard let current = Activity<ACIMDailyMinuteAttributes>.activities.first else { return }
                let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(dismissInterval))
                await current.update(content)
            }
            return
        }

        let attributes = ACIMDailyMinuteAttributes()
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(dismissInterval))

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            scheduleDismissal(for: activity.id, lessonNumber: lessonNumber)
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    static func endAllActivities() {
        Task { @MainActor in
            for activity in Activity<ACIMDailyMinuteAttributes>.activities {
                let finalState = ACIMDailyMinuteAttributes.ContentState(
                    minuteText: "Today's reading complete",
                    lessonNumber: activity.content.state.lessonNumber,
                    publishedAt: Date()
                )
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(30)))
            }
        }
    }

    private static func scheduleDismissal(for activityId: String, lessonNumber: Int?) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(dismissInterval))
            for activity in Activity<ACIMDailyMinuteAttributes>.activities where activity.id == activityId {
                let finalState = ACIMDailyMinuteAttributes.ContentState(
                    minuteText: "Today's reading complete",
                    lessonNumber: lessonNumber,
                    publishedAt: Date()
                )
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(30)))
            }
        }
    }
}
#endif
