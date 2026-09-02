import Foundation

/// Where a reference into the Text points.
///
/// Distinct value types rather than bare integers on purpose: the Read tab's
/// `NavigationStack` already routes `Int` to `LessonDetailView`, so a chapter
/// number pushed as an `Int` would silently open a Workbook lesson.
struct TextChapterRef: Hashable {
    let chapter: Int
}

struct TextSectionRef: Hashable {
    let chapter: Int
    let section: Int
    /// Set when the section is opened on a search hit.
    var spotlight: ReadingSpotlight? = nil
}

/// A lesson opened on a search hit. Bare `Int` is already the lesson
/// destination and stays so for deep links; this ref exists to carry the words.
struct LessonRef: Hashable {
    let lessonNumber: Int
    var spotlight: ReadingSpotlight? = nil
}
