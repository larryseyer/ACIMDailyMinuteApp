import Foundation
import SwiftData

@Model
final class Channel {
    var id: String = ""
    var name: String = ""
    var baseURL: String = "https://www.acimdailyminute.org"

    init() {}
}
