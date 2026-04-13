import Foundation
import SwiftData

@Model
final class DailyMinute {
    var segmentId: Int = 0
    @Attribute(.unique) var segmentHash: String = ""
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
