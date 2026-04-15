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
            minuteText: latestText,
            lessonNumber: lessonNumber,
            publishedAt: publishedDate
        )

        if let current = Activity<ACIMDailyMinuteAttributes>.activities.first {
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(dismissInterval))
            Task { @MainActor in
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
        let activities = Activity<ACIMDailyMinuteAttributes>.activities
        Task { @MainActor in
            for activity in activities {
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
