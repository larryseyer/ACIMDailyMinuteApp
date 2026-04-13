import Foundation

/// View-layer merge of whatever we locally know about a single workbook lesson.
///
/// Built in `LessonsView` by `.reduce(into:)`-ing the two SwiftData `@Query`
/// result sets (authoritative `DailyLesson` rows + lightweight `ArchivedReading`
/// rows where `channel == "daily-lesson"`). A `DailyLesson` hit always wins over
/// an archive hit because it carries the full text.
struct LessonMeta: Hashable {
    let lessonNumber: Int
    let title: String?
    let dateRead: String?
    let hasFullText: Bool
}
