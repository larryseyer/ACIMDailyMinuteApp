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
