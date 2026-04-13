import Foundation
import SwiftData

/// Downloads archive metadata and day files from www.acimdailyminute.org and persists
/// parsed stories into SwiftData as `ArchivedStory` rows.
///
/// SwiftData is the single source of truth for archive content. Views query
/// `ArchivedStory` directly via `@Query` / `FetchDescriptor`; this service is
/// the sole writer. Re-fetching an already-cached day is cheap — it skips the
/// network entirely and returns the existing rows.
///
/// Runs on the main actor because SwiftData's `ModelContext` is itself
/// main-actor-isolated. The network work inside `async` methods still hops
/// off the main actor under the hood; only the context interactions are
/// bound to it.
@MainActor
final class ArchiveService {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Index

    /// Fetches the list of available archive dates from www.acimdailyminute.org.
    ///
    /// The remote `index.json` is sorted newest-first (descending). Callers that
    /// want the most recent N dates should use `.prefix(N)`, not `.suffix(N)`.
    func fetchIndex(baseURL: String = "https://www.acimdailyminute.org") async throws -> [String] {
        let url = URL(string: "\(baseURL)/archive/index.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let index = try JSONDecoder().decode(ArchiveIndex.self, from: data)
        return index.dates
    }

    // MARK: - Day

    /// Returns all parsed stories for a given archive day.
    ///
    /// Reads from SwiftData first. If the day hasn't been ingested yet, downloads
    /// the compressed archive file, parses it, persists each line as an
    /// `ArchivedStory`, and returns the new rows. Both code paths return rows that
    /// are already attached to the shared model container.
    func fetchDay(dateString: String, baseURL: String = "https://www.acimdailyminute.org") async throws -> [ArchivedStory] {
        let context = ModelContext(modelContainer)

        // 1. SwiftData cache
        let cachePredicate = #Predicate<ArchivedStory> { $0.dateString == dateString }
        let cached = try context.fetch(FetchDescriptor<ArchivedStory>(predicate: cachePredicate))
        if !cached.isEmpty {
            return cached
        }

        // 2. Network
        let components = dateString.split(separator: "-")
        guard components.count == 3 else { throw ArchiveError.invalidDate }
        let year = components[0]

        let url = URL(string: "\(baseURL)/archive/\(year)/\(dateString).txt.gz")!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let decompressed = GzipUtility.decompress(data),
              let text = String(data: decompressed, encoding: .utf8)
        else {
            throw ArchiveError.decompressionFailed
        }

        // 3. Parse + persist
        let parsed = ArchiveLineParser.parse(rawText: text, dateString: dateString)
        for story in parsed {
            context.insert(story)
        }

        // Unique-hash collisions (e.g., from a concurrent prefetch racing against
        // the same day) surface here. Swallow them: the first save wins and the
        // other call simply returns whatever's cached on its next invocation.
        do {
            try context.save()
        } catch {
            print("[ArchiveService] save \(dateString) failed: \(error)")
        }

        return parsed
    }

    // MARK: - Prefetch

    /// Eagerly fetches the most recent archive days into SwiftData so the
    /// Archive tab's search is immediately populated on first launch.
    ///
    /// Note `.prefix(30)` — the remote index is sorted newest-first, so prefix
    /// gives us the most recent entries. Individual day fetches fail silently;
    /// search remains live against whatever successfully cached.
    func prefetchAll() async {
        do {
            let dates = try await fetchIndex()
            for dateString in dates.prefix(30) {
                _ = try? await fetchDay(dateString: dateString)
            }
        } catch {
            // Graceful degradation — nothing to prefetch, search still works
            // against any days already cached from prior sessions.
        }
    }

    // MARK: - Legacy cleanup

    /// Removes the stale `search_index.sqlite` file left behind by the
    /// pre-refactor `SearchIndexer`. Runs once per install, gated by a
    /// `UserDefaults` flag. No-op after the first successful call.
    ///
    /// Kept here (rather than, say, `@main` App init) because it's conceptually
    /// part of the archive/search storage story this type owns.
    static func cleanupLegacySearchIndex() {
        let defaultsKey = "hasCleanedLegacyFTS5"
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: defaultsKey) }

        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return }

        let dbURL = documentsURL.appendingPathComponent("search_index.sqlite")
        try? FileManager.default.removeItem(at: dbURL)
        // Also remove SQLite sidecar files that FTS5 sometimes leaves.
        for suffix in ["-shm", "-wal", "-journal"] {
            let sidecar = documentsURL.appendingPathComponent("search_index.sqlite\(suffix)")
            try? FileManager.default.removeItem(at: sidecar)
        }
    }
}

struct ArchiveIndex: Codable, Sendable {
    let dates: [String]
}

enum ArchiveError: Error {
    case invalidDate
    case decompressionFailed
}
