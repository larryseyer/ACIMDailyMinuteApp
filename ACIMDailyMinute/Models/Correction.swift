import Foundation
import SwiftData

@Model
final class Correction {
    var storyId: String = ""
    var originalFact: String = ""
    var correctedFact: String = ""
    var reason: String = ""
    var correctingSources: [String] = []
    var correctedAt: Date = Date()
    var type: String = ""

    init() {}
}
