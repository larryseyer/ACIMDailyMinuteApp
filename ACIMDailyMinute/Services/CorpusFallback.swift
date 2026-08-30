import Foundation

/// What a reader can read when the feed cannot answer.
///
/// This never tries to guess the publisher's choice. The pipeline picks a random
/// unused segment each day — all 158 observed transitions jump — so any
/// client-side guess would simply be wrong. This picks its own reading, and only
/// when there is no fresh one to show.
enum CorpusFallback {
    /// How far behind the newest feed entry may fall before the corpus answers.
    /// A count of days, deliberately not a date: nothing here expires.
    static let stalenessThresholdDays = 2

    static func isStale(newest: Date?, now: Date = Date()) -> Bool {
        guard let newest else { return true }
        let calendar = LessonSchedule.publicationCalendar
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: newest),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return days > stalenessThresholdDays
    }

    /// Deterministic: the same date yields the same segment on every device, so
    /// phone, widget and watch agree without coordinating.
    static func segment(for date: Date, corpus: CorpusService = .shared) -> CorpusSegment? {
        let ids = corpus.allSegmentIDs
        guard !ids.isEmpty else { return nil }

        let calendar = LessonSchedule.publicationCalendar
        var epoch = DateComponents()
        epoch.year = 2026
        epoch.month = 1
        epoch.day = 1
        guard let start = calendar.date(from: epoch) else { return nil }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        let index = ((days % ids.count) + ids.count) % ids.count
        return corpus.segment(id: ids[index])
    }
}
