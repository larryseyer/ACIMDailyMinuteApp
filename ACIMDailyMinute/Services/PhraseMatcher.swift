import Foundation

/// Shared phrase-matching logic used by both the foreground refresh
/// (Daily Minute and Daily Lesson views) and the background refresh
/// (`BackgroundRefreshManager`). Renamed from `WatchedTermMatcher` —
/// "phrases" reflects ACIM's longer, sentence-shaped patterns the user
/// is likely to watch (e.g. "the Holy Spirit", "real world") versus
/// JTFNews's single-word terms.
///
/// Dedup is keyed by `itemKey` (e.g. `"minute:{hash}"` or `"lesson:{N}"`)
/// stored in `PhraseStorage.notifiedItemKeys`. The same item won't
/// re-fire even across multiple foreground/background passes within the
/// same publication day.
enum PhraseMatcher {

    struct Match: Sendable {
        let itemKey: String
        let text: String
        let matchedPhrase: String
    }

    /// Returns a single-element array if today's Daily Minute matches any
    /// configured phrase and hasn't been notified yet. Returns empty
    /// otherwise. (Singular-by-design — the endpoint only ever ships one
    /// "current" minute per call.)
    static func findNewMatches(inMinute dto: DailyMinuteResponse) -> [Match] {
        let phrases = PhraseStorage.phrases
        guard !phrases.isEmpty else { return [] }

        let segmentHash = HashUtility.sha256Truncated("minute:\(dto.segment_id)|\(dto.date)|\(dto.text)")
        let itemKey = "minute:\(segmentHash)"

        guard !PhraseStorage.notifiedItemKeys.contains(itemKey) else { return [] }

        let lowText = dto.text.lowercased()
        guard let phrase = phrases.first(where: { lowText.contains($0.lowercased()) })
        else { return [] }

        return [Match(itemKey: itemKey, text: dto.text, matchedPhrase: phrase)]
    }

    /// Lessons match by `lessonNumber` rather than content hash because the
    /// lesson title and body are both candidate match surfaces — folding
    /// them together for the search keeps `Phrases` UX intuitive ("match
    /// the words I see on screen, regardless of where they appear").
    static func findNewMatches(inLesson dto: DailyLessonResponse) -> [Match] {
        let phrases = PhraseStorage.phrases
        guard !phrases.isEmpty else { return [] }

        let itemKey = "lesson:\(dto.lesson_id)"

        guard !PhraseStorage.notifiedItemKeys.contains(itemKey) else { return [] }

        let lowHaystack = "\(dto.title) \(dto.text)".lowercased()
        guard let phrase = phrases.first(where: { lowHaystack.contains($0.lowercased()) })
        else { return [] }

        return [Match(itemKey: itemKey, text: dto.text, matchedPhrase: phrase)]
    }

    /// Records the supplied keys as notified so they won't re-trigger.
    /// Caller passes only keys that were actually surfaced to the user
    /// (i.e. the result of a successful `sendNotification`), not the full
    /// set of candidates.
    static func markAllNotified(itemKeys: [String]) {
        var existing = PhraseStorage.notifiedItemKeys
        for key in itemKeys { existing.insert(key) }
        PhraseStorage.notifiedItemKeys = existing
    }
}
