import Foundation

#if os(iOS)
import ActivityKit

/// Drives the Live Activity surface (Lock Screen + Dynamic Island) for
/// freshly published Daily Minute and Daily Lesson readings. 5-minute
/// auto-dismiss, gated on the `notifyLiveActivities` user preference,
/// single shared activity per app session that updates in place.
///
/// The ContentState shape: `channel` (`"daily-minute"` or `"daily-lesson"`),
/// `latestText`, `publishedDate`, and an optional `lessonNumber` (only set
/// for the lessons channel).
enum LiveActivityManager {
    /// Auto-dismiss window. Daily readings are short and once-a-day, so a
    /// long-lived activity would clutter the Lock Screen long after the user
    /// has read it.
    private static let dismissInterval: TimeInterval = 5 * 60

    /// Starts a Live Activity if none is running, or updates the existing
    /// one in place. Caller is responsible for only invoking this when a
    /// genuinely new segment arrives — `DataService.persistMinute/Lesson`
    /// gates on `existing == nil` so spurious re-fetches don't reset the
    /// 5-minute timer.
    static func startOrUpdate(
        channel: String,
        latestText: String,
        publishedDate: Date,
        lessonNumber: Int? = nil
    ) {
        guard UserDefaults.standard.bool(forKey: "notifyLiveActivities") else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = ACIMActivityAttributes.ContentState(
            channel: channel,
            latestText: latestText,
            publishedDate: publishedDate,
            lessonNumber: lessonNumber
        )

        if let current = Activity<ACIMActivityAttributes>.activities.first {
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(dismissInterval))
            Task { @MainActor in
                await current.update(content)
            }
            return
        }

        let attributes = ACIMActivityAttributes()
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(dismissInterval))

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            scheduleDismissal(for: activity.id, channel: channel, lessonNumber: lessonNumber)
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    /// Ends every running activity with a "reading complete" final state.
    /// Preserves `channel` from each activity so the dismissal frame doesn't
    /// suddenly switch context (e.g. lessons activity ending with a minute
    /// label).
    static func endAllActivities() {
        let activities = Activity<ACIMActivityAttributes>.activities
        Task { @MainActor in
            for activity in activities {
                let finalState = ACIMActivityAttributes.ContentState(
                    channel: activity.content.state.channel,
                    latestText: "Today's reading complete",
                    publishedDate: Date(),
                    lessonNumber: activity.content.state.lessonNumber
                )
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(30)))
            }
        }
    }

    private static func scheduleDismissal(for activityId: String, channel: String, lessonNumber: Int?) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(dismissInterval))
            for activity in Activity<ACIMActivityAttributes>.activities where activity.id == activityId {
                let finalState = ACIMActivityAttributes.ContentState(
                    channel: channel,
                    latestText: "Today's reading complete",
                    publishedDate: Date(),
                    lessonNumber: lessonNumber
                )
                let finalContent = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .after(Date().addingTimeInterval(30)))
            }
        }
    }
}
#endif
