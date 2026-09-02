import Foundation

/// The one numbered reference the Course makes to itself, and the link it
/// becomes.
///
/// Measured over the whole bundle before this was written: the Course never
/// cites itself by address — no `T-`, no `W-`, no "Lesson N" in the prose —
/// but the seventy review lessons revisit earlier lessons by number, set in
/// brackets: `[181] "I trust my brothers, who are one with me."` There are
/// exactly 150 of them, all in review lessons, all pointing earlier, none in
/// the Text, the Manual or the Part Introductions; the only other brackets in
/// the Workbook are the reader's blanks, `[name of person]`, which carry no
/// digits. `tools/verify_cross_references.sh` holds every one of those facts.
///
/// Pure by design — no SwiftUI, no `Bundle`, no `CorpusService`, no
/// `ReadingKey` — so that harness can compile it alone.
enum CrossReference {
    /// One bracketed lesson number, as `Character` offsets into the display
    /// string it was found in.
    struct LessonReference: Hashable, Sendable {
        let range: Range<Int>
        let lesson: Int
    }

    static let lessonRange = 1...365

    /// Every `[N]` with N in 1...365, in order of appearance, never overlapping.
    ///
    /// ⛔ `Character` offsets, never UTF-16: every stored highlight offset is a
    /// `Character` count, and the ranges here are painted through the same
    /// conversion a highlight uses.
    static func lessonReferences(in display: String) -> [LessonReference] {
        var found: [LessonReference] = []
        var offset = 0
        var openAt: Int? = nil
        var digits = ""
        for character in display {
            defer { offset += 1 }
            if character == "[" {
                openAt = offset
                digits = ""
                continue
            }
            guard openAt != nil else { continue }
            if character.isASCII, character.isNumber {
                digits.append(character)
            } else if character == "]" {
                if let start = openAt, !digits.isEmpty, digits.count <= 3,
                   let lesson = Int(digits), lessonRange.contains(lesson) {
                    found.append(LessonReference(range: start..<(offset + 1), lesson: lesson))
                }
                openAt = nil
            } else {
                openAt = nil
            }
        }
        return found
    }

    /// The value a link carries in the text view. A private scheme the app
    /// never registers, so a value that somehow reached the system would open
    /// nothing at all.
    private static let scheme = "reading"

    static func url(forLesson lesson: Int) -> URL {
        URL(string: "\(scheme):lesson/\(lesson)")!
    }

    /// Nil unless the scheme, the path and the range all hold: a URL that was
    /// not made by `url(forLesson:)` is not a lesson.
    static func lesson(from url: URL) -> Int? {
        guard url.scheme == scheme else { return nil }
        let path = url.absoluteString.dropFirst(scheme.count + 1)
        guard path.hasPrefix("lesson/"),
              let lesson = Int(path.dropFirst("lesson/".count)),
              lessonRange.contains(lesson)
        else { return nil }
        return lesson
    }
}
