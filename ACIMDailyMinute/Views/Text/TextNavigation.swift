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

/// A lesson opened on a search hit or a cross-reference. Bare `Int` is already
/// the lesson destination and stays so for lists and deep links; this ref
/// exists to carry the words, and to say whether arriving is a request to
/// watch.
struct LessonRef: Hashable {
    let lessonNumber: Int
    var spotlight: ReadingSpotlight? = nil
    /// False when the reader followed a reference from inside another reading:
    /// that is a request to read, and the video would take the screen.
    var presentsVideo: Bool = true
}
