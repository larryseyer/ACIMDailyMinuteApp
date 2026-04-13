import Foundation
import SwiftData

@Model
final class Source {
    var id: String = ""
    var name: String = ""
    var accuracy: Double = 0.0
    var bias: Double = 0.0
    var speed: Double = 0.0
    var consensus: Double = 0.0
    var controlType: String = ""
    var owner: String = ""
    var ownerDisplay: String = ""

    init() {}
}
