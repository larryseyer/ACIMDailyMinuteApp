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
}
