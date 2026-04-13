#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

struct ACIMActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var channel: String
        var latestText: String
        var publishedDate: Date
        var lessonNumber: Int?
    }
}
#endif
