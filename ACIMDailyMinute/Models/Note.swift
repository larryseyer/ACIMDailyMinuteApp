import Foundation
import SwiftData

/// Something the reader wrote. Many per reading, by design — review periods send
/// a reader back to the same lesson years apart, and the second thought must not
/// overwrite the first.
///
/// `highlightID` present means a thought about a passage; absent means a thought
/// about the whole reading. Both are ordinary.
@Model
final class Note {
    @Attribute(.unique) var id: UUID = UUID()
    var readingKey: String = ""
    var body: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var highlightID: UUID?

    init() {}
}
