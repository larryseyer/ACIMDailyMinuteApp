import Foundation

enum ShareTextBuilder {
    static func minuteShareText(_ minute: DailyMinute) -> String {
        var parts: [String] = [minute.text]
        let reference = minute.sourceReference.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reference.isEmpty {
            parts.append("— A Course in Miracles, \(reference)")
        }
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }

    static func lessonShareText(_ lesson: DailyLesson) -> String {
        let header = "Lesson \(lesson.lessonNumber): \(lesson.lessonTitle)"
        var parts: [String] = [header, lesson.text]
        parts.append("— A Course in Miracles, Workbook for Students")
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }

    /// Matches `minuteShareText`'s format verbatim so the share sheet output
    /// looks identical regardless of whether a user shared from Today or Archive.
    static func archivedMinuteShareText(_ reading: ArchivedReading) -> String {
        var parts: [String] = [reading.text]
        let reference = reading.sourceReference.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reference.isEmpty {
            parts.append("— A Course in Miracles, \(reference)")
        }
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }

    /// Archive lesson entries only carry a title (stored in `reading.text` per
    /// `ArchiveService.persistInlineLessons`), so this output is title-only —
    /// unlike `lessonShareText`, which includes the full body. The trailing
    /// attribution lines stay consistent with the Workbook framing.
    static func archivedLessonShareText(_ reading: ArchivedReading) -> String {
        let n = reading.lessonNumber ?? 0
        let title = reading.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let header = title.isEmpty ? "Lesson \(n)" : "Lesson \(n): \(title)"
        var parts: [String] = [header]
        parts.append("— A Course in Miracles, Workbook for Students")
        parts.append("www.acimdailyminute.org")
        return parts.joined(separator: "\n\n")
    }
}
