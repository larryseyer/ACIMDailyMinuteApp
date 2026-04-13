import Foundation

#if os(iOS)
import ActivityKit

enum LiveActivityManager {
    private static let dismissInterval: TimeInterval = 5 * 60 // 5 minutes

    static func startOrUpdate(storyCount: Int, latestFact: String, publishedDate: Date) {
        guard UserDefaults.standard.bool(forKey: "notifyLiveActivities") else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = ACIMActivityAttributes.ContentState(
            storyCount: storyCount,
            latestFact: latestFact,
            publishedDate: publishedDate
        )

        // Update existing activity if one is running
        if let current = Activity<ACIMActivityAttributes>.activities.first {
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(dismissInterval))
            Task { @MainActor in
                await current.update(content)
            }
            return
        }

        // Start a new activity
        let attributes = ACIMActivityAttributes()
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(dismissInterval))

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            scheduleDismissal(for: activity.id)
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    static func endAllActivities() {
        let finalState = ACIMActivityAttributes.ContentState(
            storyCount: 0,
            latestFact: "Caught up",
            publishedDate: Date()
        )
        let finalContent = ActivityContent(state: finalState, staleDate: nil)

        let activities = Activity<ACIMActivityAttributes>.activities
        Task { @MainActor in
            for activity in activities {
                await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(30)))
            }
        }
    }

    private static func scheduleDismissal(for activityId: String) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(dismissInterval))
            for activity in Activity<ACIMActivityAttributes>.activities where activity.id == activityId {
                let finalState = ACIMActivityAttributes.ContentState(
                    storyCount: 0,
                    latestFact: "Caught up",
                    publishedDate: Date()
                )
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(30)))
            }
        }
    }
}
#endif
