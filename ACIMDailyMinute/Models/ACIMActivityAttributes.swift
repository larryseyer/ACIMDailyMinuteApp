#if canImport(ActivityKit) && os(iOS)
#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation

struct ACIMDailyMinuteAttributes: ActivityAttributes {
    static let name: String = "Daily Minute"

    struct ContentState: Codable, Hashable {
        var minuteText: String
        var lessonNumber: Int?
        var publishedAt: Date
    }
}
#endif
