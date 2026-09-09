import Foundation

/// Where a Workbook lesson's MP3 lives, and how a television finds it.
///
/// ⛔ **The DailyLesson JSON row is today's lesson.** Jump-to-47 is not today.
/// The podcast feed (`/podcast-lessons.xml`) is the catalogue: lesson 47's
/// enclosure is `lesson-047.mp3` on archive.org whether or not that number
/// is in SwiftData as a `DailyLesson`. Read used to look only at the JSON
/// row, so 47 and 49 (and every other past lesson) played silent.
///
/// Free of SwiftUI and SwiftData so `tools/verify_tv_player.sh` can compile
/// this file alone against the real feed titles and guids.
enum LessonNarration {
    /// `"Lesson 47: …"` → 47. `"Introduction"` → 0. Anything else → nil.
    static func number(fromTitle title: String) -> Int? {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if trimmed == "Introduction" { return 0 }
        guard trimmed.hasPrefix("Lesson ") else { return nil }
        let digits = trimmed.dropFirst("Lesson ".count).prefix(while: \.isNumber)
        return Int(digits)
    }

    /// `"acim-lesson-047"` → 47. `"acim-lesson-000"` → 0.
    static func number(fromGUID guid: String) -> Int? {
        let prefix = "acim-lesson-"
        guard guid.lowercased().hasPrefix(prefix) else { return nil }
        return Int(guid.dropFirst(prefix.count))
    }

    /// `"lesson:47"`, `"intro:0"`, `"archive-lesson:49"`.
    static func number(fromPlayerID id: String) -> Int? {
        for prefix in ["lesson:", "intro:", "archive-lesson:"] where id.hasPrefix(prefix) {
            return Int(id.dropFirst(prefix.count))
        }
        return nil
    }

    /// First non-empty URL. Empty string is not a URL — the JSON emits it
    /// for a lesson that has a row and no file.
    static func url(daily: String?, archived: String?, podcast: String?) -> String? {
        for candidate in [daily, archived, podcast] {
            if let value = candidate, !value.isEmpty { return value }
        }
        return nil
    }

    /// The enclosure the feed named for this lesson number, or nil.
    static func podcastURL(
        forLesson lesson: Int,
        episodes: [(id: String, title: String, audioURL: String)]
    ) -> String? {
        for episode in episodes {
            let matches = number(fromGUID: episode.id) == lesson
                || number(fromTitle: episode.title) == lesson
            guard matches, !episode.audioURL.isEmpty else { continue }
            return episode.audioURL
        }
        return nil
    }
}
