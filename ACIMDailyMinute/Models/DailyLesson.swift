import Foundation
import SwiftData

@Model
final class DailyLesson {
    @Attribute(.unique) var lessonNumber: Int = 0
    var lessonTitle: String = ""
    var segmentId: Int = 0
    var segmentHash: String = ""
    var date: String = ""
    var publishedAt: Date = Date()
    var text: String = ""
    var sourcePDF: String = ""
    var sourceReference: String = ""
    var wordCount: Int = 0
    var audioURL: String?
    var youtubeURL: String?
    var youtubeID: String?
    var tiktokURL: String?

    init() {}
}

extension DailyLesson {
    /// The publisher's `text` payload is hard-wrapped at ~60 chars with literal
    /// `\n` breaks. Left as-is, SwiftUI honors those hard breaks and pins the
    /// rendered line width to the pre-broken column — which makes the lesson
    /// card's visible text edge fall short of the Daily Minute card's (the
    /// minute feed has no embedded newlines). Replacing `\n` with a space lets
    /// `Text` flow naturally to the container width so both cards read edge-to-edge.
    var displayText: String {
        text.replacingOccurrences(of: "\n", with: " ")
    }
}
