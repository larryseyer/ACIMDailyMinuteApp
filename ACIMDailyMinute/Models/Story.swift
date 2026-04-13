import Foundation
import SwiftData

@Model
final class Story {
    var id: String = ""
    var storyHash: String = ""
    var fact: String = ""
    var sourceDisplay: String = ""
    var sourceURLs: [String: String] = [:]
    var audioURL: String?
    var publishedAt: Date = Date()
    var status: String = ""
    var isCorrection: Bool = false

    init() {}
}
