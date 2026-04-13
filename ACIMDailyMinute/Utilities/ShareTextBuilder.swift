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
}
