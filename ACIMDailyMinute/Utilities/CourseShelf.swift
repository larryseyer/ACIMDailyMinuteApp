import Foundation

/// The four books of the Course.
///
/// Case order is contents order: Minute first, then Lesson, Text, Manual.
/// Raw values stay the short labels so existing compile checks on order
/// still mean the same four books. The contents page draws `bookName`.
enum CourseShelf: String, CaseIterable, Identifiable, Sendable {
    case minute = "Minute"
    case lesson = "Lesson"
    case text = "Text"
    case manual = "Manual"

    var id: String { rawValue }

    var bookName: String {
        switch self {
        case .minute: "Daily Minute"
        case .lesson: "Workbook"
        case .text: "Text"
        case .manual: "Manual"
        }
    }
}
