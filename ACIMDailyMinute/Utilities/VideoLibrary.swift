import Foundation

/// What the Video tab can name, and whether a row plays YouTube or composes.
///
/// Foundation only — `tools/verify_video_compose.sh` compiles this file
/// and nothing else. Ids are resolved by the caller (`YouTubeID.candidates`).
/// An empty list is not a miss of the Course: the row still exists, and
/// the player is composition. This file does not invent TTS, host MP4s,
/// or match a Daily Minute recording onto a Text section.
enum VideoLibrary {
    struct Row: Equatable, Sendable {
        var id: String
        var title: String
        var videoIDs: [String]
    }

    enum Play: Equatable, Sendable {
        case youtube([String])
        case compose
    }

    static func play(videoIDs: [String], youtubeAvailable: Bool) -> Play {
        let ids = videoIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if youtubeAvailable, !ids.isEmpty { return .youtube(ids) }
        return .compose
    }

    static func lessonRows(
        titles: [Int: String],
        videoIDsByLesson: [Int: [String]],
        introductions: [(number: Int, title: String, insertBefore: Int)]
    ) -> [Row] {
        let intros = introductions.sorted {
            ($0.insertBefore, $0.number) < ($1.insertBefore, $1.number)
        }
        var rows: [Row] = []
        rows.reserveCapacity(365 + intros.count)
        for n in 1...365 {
            for intro in intros where intro.insertBefore == n {
                rows.append(Row(
                    id: "intro:\(intro.number)",
                    title: intro.title,
                    videoIDs: videoIDsByLesson[intro.number] ?? []
                ))
            }
            rows.append(Row(
                id: "lesson:\(n)",
                title: titles[n] ?? "Lesson \(n)",
                videoIDs: videoIDsByLesson[n] ?? []
            ))
        }
        return rows
    }

    static func textSectionRows(
        chapter: Int,
        sections: [(number: Int, title: String)],
        videoIDsBySection: [Int: [String]]
    ) -> [Row] {
        sections.map { section in
            Row(
                id: "text:\(chapter).\(section.number)",
                title: section.title,
                videoIDs: videoIDsBySection[section.number] ?? []
            )
        }
    }

    static func manualSectionRows(
        sections: [(number: Int, title: String)],
        videoIDsByNumber: [Int: [String]]
    ) -> [Row] {
        sections.map { section in
            Row(
                id: "manual:\(section.number)",
                title: section.title,
                videoIDs: videoIDsByNumber[section.number] ?? []
            )
        }
    }
}
