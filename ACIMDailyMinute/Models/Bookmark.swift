import Foundation
import SwiftData

@Model
final class Bookmark {
    @Attribute(.unique) var storyId: String = ""
    var createdAt: Date = Date()

    init() {}
}
