import Foundation
import SwiftData
import WidgetKit

/// Two-phase service: network I/O returns DTOs; persistence is `@MainActor`
/// and writes into a caller-supplied `ModelContext`. Writing through the
/// SwiftUI-injected context lets `@Query` observe the changes immediately
/// without relying on cross-context auto-merge (which isn't reliable on
/// iOS 17).
struct DataService: Sendable {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Fetch (pure I/O — returns DTOs, no persistence)

    /// Two gates stand between a caller and fresh JSON, and `force` opens both.
    ///
    /// The first is our own `FetchCooldown`, which keeps passive on-appear
    /// loads from re-polling every time a view redraws. The second is HTTP:
    /// GitHub Pages serves these files with a `Cache-Control` max-age, so
    /// inside that window `URLSession.shared` answers from `URLCache` without
    /// asking origin anything. Clearing only the cooldown — which is what
    /// pull-to-refresh used to do — gets past the first gate and hands the
    /// user the same stale bytes from behind the second.
    ///
    /// `force: true` skips the cooldown and switches the request to
    /// `.reloadRevalidatingCacheData`, which sends `If-None-Match` /
    /// `If-Modified-Since` and takes the 304 fast path when nothing changed.
    /// Same contract as `PodcastService.fetchMinuteEpisodes(force:)`.
    ///
    /// Returns `nil` if the cooldown window blocks the fetch.
    func fetchDailyMinute(
        baseURL: String = "https://www.acimdailyminute.org",
        force: Bool = false
    ) async throws -> DailyMinuteResponse? {
        guard let data = try await fetchJSON(
            path: "/daily-minute.json",
            baseURL: baseURL,
            cooldownKey: FetchCooldownKey.dailyMinute,
            force: force
        ) else { return nil }
        return try JSONDecoder().decode(DailyMinuteResponse.self, from: data)
    }

    /// Same contract as `fetchDailyMinute(baseURL:force:)`, for the lesson
    /// endpoint. Returns `nil` if the cooldown window blocks the fetch.
    func fetchDailyLesson(
        baseURL: String = "https://www.acimdailyminute.org",
        force: Bool = false
    ) async throws -> DailyLessonResponse? {
        guard let data = try await fetchJSON(
            path: "/daily-lesson.json",
            baseURL: baseURL,
            cooldownKey: FetchCooldownKey.dailyLesson,
            force: force
        ) else { return nil }
        return try JSONDecoder().decode(DailyLessonResponse.self, from: data)
    }

    /// Returns `nil` when the cooldown blocks the call; otherwise the raw
    /// response body. Decoding stays with the caller so each endpoint keeps
    /// its own DTO type.
    private func fetchJSON(
        path: String,
        baseURL: String,
        cooldownKey: String,
        force: Bool
    ) async throws -> Data? {
        if !force {
            guard FetchCooldown.shouldFetch(
                key: cooldownKey,
                interval: FetchCooldownInterval.live
            ) else { return nil }
        }

        let url = URL(string: "\(baseURL)\(path)")!
        let request = URLRequest(
            url: url,
            cachePolicy: force ? .reloadRevalidatingCacheData : .useProtocolCachePolicy
        )
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    // MARK: - Store repair

    /// Bump when a content identity changes meaning.
    ///
    /// Version 2: `DailyMinute` is keyed by date and `ArchivedReading` minutes
    /// by `channel|date`, instead of by hashes that folded in the body text.
    /// Rows written under the old scheme cannot collide with rows written under
    /// the new one, so without this they linger as duplicates — which is how a
    /// phone ended up drawing a pre-correction passage while a freshly
    /// installed iPad drew the fixed one.
    static let contentSchemaVersion = 2
    private static let contentSchemaVersionKey = "contentSchemaVersion"

    /// Re-keys and de-duplicates readings written under the old identity scheme.
    ///
    /// Deliberately *not* a blanket purge, unlike the podcast cache: bookmarks
    /// point into these rows by hash, so throwing them away would orphan every
    /// saved reading. Instead each surviving row is re-keyed and any bookmark
    /// naming its old hash is rewritten in the same pass, while both values are
    /// still in hand.
    @MainActor
    static func repairContentIdentitiesIfNeeded(in context: ModelContext) throws {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: contentSchemaVersionKey) < contentSchemaVersion else { return }

        var bookmarksByKey: [String: [Bookmark]] = [:]
        for bookmark in try context.fetch(FetchDescriptor<Bookmark>()) {
            bookmarksByKey[bookmark.itemKey, default: []].append(bookmark)
        }

        // --- Archived minutes: re-key to channel|date, keeping saves attached.
        let archived = try context.fetch(FetchDescriptor<ArchivedReading>())
        var seenArchiveKeys: Set<String> = []
        for row in archived where row.channel == "daily-minute" {
            let stable = ArchiveService.minuteLineHash(date: row.dateString)
            if row.lineHash != stable {
                for bookmark in bookmarksByKey["minute:\(row.lineHash)"] ?? [] {
                    bookmark.itemKey = "minute:\(stable)"
                }
                row.lineHash = stable
            }
            // A date already seen is a superseded copy of the same reading.
            if seenArchiveKeys.contains(stable) {
                context.delete(row)
            } else {
                seenArchiveKeys.insert(stable)
            }
        }

        // --- Daily Minutes: one row per date. Keep whichever a bookmark
        //     references so the save survives; the current fetch overwrites the
        //     survivor's text moments later.
        var minutesByDate: [String: [DailyMinute]] = [:]
        for minute in try context.fetch(FetchDescriptor<DailyMinute>()) {
            minutesByDate[minute.date, default: []].append(minute)
        }
        for (_, rows) in minutesByDate where rows.count > 1 {
            let keeper = rows.first { bookmarksByKey["minute:\($0.segmentHash)"] != nil } ?? rows[0]
            for row in rows where row !== keeper {
                context.delete(row)
            }
        }

        try context.save()
        defaults.set(contentSchemaVersion, forKey: contentSchemaVersionKey)
    }

    // MARK: - Persist (MainActor — writes into caller's ModelContext)

    /// Upserts the Daily Minute and its inline archive into `context`, saves,
    /// marks the cooldown, and fires downstream side-effects (widget reload,
    /// Live Activity start when a *new* segment arrives).
    @MainActor
    @discardableResult
    static func persistMinute(_ dto: DailyMinuteResponse, in context: ModelContext) throws -> DailyMinuteResponse {
        try repairContentIdentitiesIfNeeded(in: context)

        let publishedAt = parseISODate(dto.date) ?? Date()

        // Look up by date, not by a hash of the text. There is exactly one
        // Daily Minute per day, so the date is the real key. Hashing the body
        // meant any correction the publisher made — the paragraph repair, for
        // one — produced a different hash, missed this lookup, and inserted a
        // *second* row for the same day. Both rows then shared a `publishedAt`,
        // so which one the Today tab drew was arbitrary, and devices that had
        // been running since before the edit kept showing the old text.
        let date = dto.date
        let descriptor = FetchDescriptor<DailyMinute>(
            predicate: #Predicate { $0.date == date }
        )
        let existing = try context.fetch(descriptor).first
        let isNew = existing == nil

        let minute = existing ?? DailyMinute()
        // `segmentHash` is the unique attribute and doubles as the bookmark key
        // (`"minute:\(segmentHash)"`). Once assigned it never changes, or saved
        // readings would orphan every time the text was corrected. New rows only.
        if isNew {
            minute.segmentHash = HashUtility.sha256Truncated(
                "minute:\(dto.segment_id)|\(dto.date)|\(dto.text)"
            )
        }
        minute.segmentId = dto.segment_id
        minute.date = dto.date
        minute.publishedAt = publishedAt
        minute.text = dto.text
        minute.sourcePDF = dto.source_pdf
        minute.sourceReference = dto.source_reference
        minute.wordCount = dto.word_count
        minute.audioURL = dto.audio_url.isEmpty ? nil : dto.audio_url
        minute.youtubeURL = dto.youtube_url.isEmpty ? nil : dto.youtube_url
        minute.youtubeID = dto.youtube_id.isEmpty ? nil : dto.youtube_id
        minute.tiktokURL = dto.tiktok_url.isEmpty ? nil : dto.tiktok_url
        if isNew { context.insert(minute) }

        try ArchiveService.persistInlineMinutes(dto.archive, in: context)

        try context.save()
        FetchCooldown.markFetched(key: FetchCooldownKey.dailyMinute)
        WidgetCenter.shared.reloadAllTimelines()

        #if os(iOS)
        if isNew {
            LiveActivityManager.startOrUpdate(
                channel: "daily-minute",
                latestText: dto.text,
                publishedDate: publishedAt
            )
        }
        PhoneWatchSyncService.shared.sendLatestMinute(minute)
        #endif

        return dto
    }

    /// Upserts the Daily Lesson and its inline archive. Mirrors `persistMinute`
    /// but keys uniqueness on `lessonNumber` (the `@Attribute(.unique)` field
    /// on `DailyLesson`).
    @MainActor
    @discardableResult
    static func persistLesson(_ dto: DailyLessonResponse, in context: ModelContext) throws -> DailyLessonResponse {
        let lessonNumber = dto.lesson_id
        let segmentHash = HashUtility.sha256Truncated("lesson:\(dto.lesson_id)|\(dto.date)|\(dto.text)")
        let publishedAt = parseISODate(dto.date) ?? Date()

        let descriptor = FetchDescriptor<DailyLesson>(
            predicate: #Predicate { $0.lessonNumber == lessonNumber }
        )
        let existing = try context.fetch(descriptor).first
        let isNew = existing == nil

        let lesson = existing ?? DailyLesson()
        lesson.lessonNumber = lessonNumber
        lesson.lessonTitle = dto.title
        lesson.segmentHash = segmentHash
        lesson.date = dto.date
        lesson.publishedAt = publishedAt
        lesson.text = dto.text
        lesson.wordCount = dto.word_count
        lesson.audioURL = dto.audio_url.isEmpty ? nil : dto.audio_url
        lesson.youtubeURL = dto.youtube_url.isEmpty ? nil : dto.youtube_url
        lesson.youtubeID = dto.youtube_id.isEmpty ? nil : dto.youtube_id
        if isNew { context.insert(lesson) }

        try ArchiveService.persistInlineLessons(dto.archive, in: context)

        try context.save()
        FetchCooldown.markFetched(key: FetchCooldownKey.dailyLesson)
        WidgetCenter.shared.reloadAllTimelines()

        #if os(iOS)
        if isNew {
            LiveActivityManager.startOrUpdate(
                channel: "daily-lesson",
                latestText: dto.text,
                publishedDate: publishedAt,
                lessonNumber: lessonNumber
            )
        }
        #endif

        return dto
    }

    // MARK: - Date Parsing

    /// Parses the `YYYY-MM-DD` strings the publisher emits in `date` fields.
    /// Falls back to ISO-8601 with time component for forward compatibility
    /// in case the publisher ever upgrades to richer timestamps.
    @MainActor
    static func parseISODate(_ string: String) -> Date? {
        let dayOnly = DateFormatter()
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        dayOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dayOnly.dateFormat = "yyyy-MM-dd"
        if let date = dayOnly.date(from: string) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: string)
    }
}

// MARK: - DTOs

/// Top-level shape of `/daily-minute.json`.
///
/// Field names use snake_case to match the publisher (`github_push.py`)
/// verbatim — no `CodingKeys` needed, which keeps drift detection trivial:
/// any new server field becomes a compile error if added here, and any
/// renamed field becomes a decode error at runtime.
struct DailyMinuteResponse: Codable, Sendable {
    let segment_id: Int
    let date: String
    let text: String
    let source_pdf: String
    let source_reference: String
    let word_count: Int
    let audio_url: String
    let youtube_url: String
    let youtube_id: String
    let tiktok_url: String
    let archive: [InlineArchiveMinuteDTO]
}

struct InlineArchiveMinuteDTO: Codable, Sendable {
    let date: String
    let text: String
    let source_reference: String
    let audio_url: String
}

/// Top-level shape of `/daily-lesson.json`. The publisher omits
/// `segment_id`, `source_pdf`, `source_reference`, and `tiktok_url` from
/// the lesson endpoint by design — model defaults handle those fields
/// (parallel-schema choice, see Phase 3.2 handoff).
struct DailyLessonResponse: Codable, Sendable {
    let lesson_id: Int
    let date: String
    let title: String
    let text: String
    let word_count: Int
    let audio_url: String
    let youtube_url: String
    let youtube_id: String
    let total_lessons: Int
    let archive: [InlineArchiveLessonDTO]
}

struct InlineArchiveLessonDTO: Codable, Sendable {
    let lesson_id: Int
    let title: String
    let date: String
    let audio_url: String
    /// Optional because feeds published before this field existed must still
    /// decode. Absent means "video unknown", never "use the playlist".
    let youtube_id: String?
}
