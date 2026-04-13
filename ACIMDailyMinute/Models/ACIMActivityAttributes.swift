#if os(iOS)
import ActivityKit
import Foundation

struct ACIMActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let storyCount: Int
        let latestFact: String
        let publishedDate: Date
    }
}
#endif
