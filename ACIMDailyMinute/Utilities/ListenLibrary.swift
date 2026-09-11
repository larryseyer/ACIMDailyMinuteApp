import Foundation

/// What the Listen tab can name, and whether a row may show play.
///
/// Foundation only — `tools/verify_listen_unplayed.sh` compiles this file
/// with `LessonNarration.swift` and nothing else. Availability is the
/// enclosure the caller already resolved from the feed. An empty string
/// is not a URL: the row still exists, play is omitted, and nothing here
/// invents TTS or matches a filename.
enum ListenLibrary {
    struct Row: Equatable, Sendable {
        var id: String
        var title: String
        var audioURL: String
        var episodeID: String
    }

    struct Resume: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case nowPlaying
            case `continue`
        }
        var kind: Kind
        var title: String
        var audioURL: String
        var episodeID: String
    }

    static func showsPlay(audioURL: String) -> Bool {
        !audioURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func minuteAudio(daily: String?, archived: String?, podcast: String?) -> String {
        LessonNarration.url(daily: daily, archived: archived, podcast: podcast) ?? ""
    }

    static func lessonRows(
        titles: [Int: String],
        audioByLesson: [Int: String],
        episodeIDByLesson: [Int: String],
        introductions: [(number: Int, title: String, insertBefore: Int)]
    ) -> [Row] {
        let intros = introductions.sorted {
            ($0.insertBefore, $0.number) < ($1.insertBefore, $1.number)
        }
        var rows: [Row] = []
        rows.reserveCapacity(365 + intros.count)
        for n in 1...365 {
            for intro in intros where intro.insertBefore == n {
                rows.append(row(
                    id: "intro:\(intro.number)",
                    title: intro.title,
                    lessonKey: intro.number,
                    audioByLesson: audioByLesson,
                    episodeIDByLesson: episodeIDByLesson
                ))
            }
            rows.append(row(
                id: "lesson:\(n)",
                title: titles[n] ?? "Lesson \(n)",
                lessonKey: n,
                audioByLesson: audioByLesson,
                episodeIDByLesson: episodeIDByLesson
            ))
        }
        return rows
    }

    static func textSectionRows(
        chapter: Int,
        sections: [(number: Int, title: String)],
        audioBySection: [Int: String],
        episodeIDBySection: [Int: String]
    ) -> [Row] {
        sections.map { section in
            let audio = audioBySection[section.number] ?? ""
            let episodeID = episodeIDBySection[section.number] ?? ""
            return Row(
                id: "text:\(chapter).\(section.number)",
                title: section.title,
                audioURL: audio,
                episodeID: episodeID.isEmpty && showsPlay(audioURL: audio)
                    ? audio
                    : episodeID
            )
        }
    }

    static func manualSectionRows(
        sections: [(number: Int, title: String)],
        audioByNumber: [Int: String],
        episodeIDByNumber: [Int: String]
    ) -> [Row] {
        sections.map { section in
            let audio = audioByNumber[section.number] ?? ""
            let episodeID = episodeIDByNumber[section.number] ?? ""
            return Row(
                id: "manual:\(section.number)",
                title: section.title,
                audioURL: audio,
                episodeID: episodeID.isEmpty && showsPlay(audioURL: audio)
                    ? audio
                    : episodeID
            )
        }
    }

    static func resume(
        hasActiveAudio: Bool,
        nowPlayingTitle: String,
        nowPlayingURL: String,
        nowPlayingEpisodeID: String,
        inProgress: [(title: String, audioURL: String, episodeID: String, updatedAt: Date)]
    ) -> Resume? {
        if hasActiveAudio, showsPlay(audioURL: nowPlayingURL) {
            return Resume(
                kind: .nowPlaying,
                title: nowPlayingTitle,
                audioURL: nowPlayingURL,
                episodeID: nowPlayingEpisodeID
            )
        }
        guard let latest = inProgress.max(by: { $0.updatedAt < $1.updatedAt }),
              showsPlay(audioURL: latest.audioURL)
        else { return nil }
        return Resume(
            kind: .continue,
            title: latest.title,
            audioURL: latest.audioURL,
            episodeID: latest.episodeID
        )
    }

    private static func row(
        id: String,
        title: String,
        lessonKey: Int,
        audioByLesson: [Int: String],
        episodeIDByLesson: [Int: String]
    ) -> Row {
        let audio = audioByLesson[lessonKey] ?? ""
        let episodeID = episodeIDByLesson[lessonKey] ?? ""
        return Row(
            id: id,
            title: title,
            audioURL: audio,
            episodeID: episodeID.isEmpty && showsPlay(audioURL: audio) ? audio : episodeID
        )
    }
}
