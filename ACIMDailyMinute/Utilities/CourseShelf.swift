import Foundation

/// The four books of the Course, as one picker on Read, Listen, and Video.
///
/// Case order is picker order: Minute first, then Lesson, Text, Manual.
/// The default on Read is still Lesson, so the Workbook landing does not
/// jump to a calendar.
enum CourseShelf: String, CaseIterable, Identifiable, Sendable {
    case minute = "Minute"
    case lesson = "Lesson"
    case text = "Text"
    case manual = "Manual"

    var id: String { rawValue }
}
