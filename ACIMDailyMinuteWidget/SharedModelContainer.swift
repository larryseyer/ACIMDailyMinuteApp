import Foundation
import SwiftData

/// Where this app's SwiftData stores live, and how every target opens them.
///
/// ⛔ **Two configurations, one container.** The reader's own work and the
/// network-derived caches sit in two separate store files, but they are opened
/// as one `ModelContainer` so a single `ModelContext` still spans both. That is
/// load-bearing rather than incidental: the widget fetches a `DailyMinute` and a
/// `Bookmark` from one context, `BackupService` resolves a `Bookmark` against a
/// `DailyMinute`, and nine views hold a `@Query` for `Bookmark` beside
/// cache-model queries. Two containers would break all of it.
///
/// The split exists for two reasons, and the constraint is only the smaller one.
/// SwiftData refuses `@Attribute(.unique)` in a CloudKit-backed store, so the
/// reader models must shed it — but enabling CloudKit over one configuration
/// would also push every cached feed reading and the whole podcast cache into
/// the reader's iCloud, which is megabytes of already-public text and none of
/// their business to store twice.
///
/// ⛔ This file is compiled into **all three targets** — app, widget extension
/// and watch — which is why the declaration lives here rather than in any one of
/// them. It used to be hand-duplicated in four places that had to be kept in
/// step by hand.
enum SharedModelContainer {
    static let appGroupIdentifier = "group.com.larryseyer.acimdailyminute"

    /// The reader's own work. Nothing anywhere can re-send these if they are
    /// lost: there is no server, no account and no analytics, by design.
    static let readerModels: [any PersistentModel.Type] = [
        Highlight.self,
        Note.self,
        Bookmark.self
    ]

    /// Everything derived from the feed or the bundle. Re-derivable by
    /// definition, and deliberately excluded from anything that syncs.
    static let cacheModels: [any PersistentModel.Type] = [
        DailyMinute.self,
        DailyLesson.self,
        ArchivedReading.self,
        Channel.self,
        CachedPodcastEpisode.self,
        SegmentMedia.self
    ]

    static var groupURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
    }

    static var readerStoreURL: URL { groupURL.appending(path: "reader.store") }
    static var cacheStoreURL: URL { groupURL.appending(path: "cache.store") }

    /// The single pre-split store. ⛔ **Never opened by `makeContainer`, and
    /// never deleted.** `ReaderStoreMigration` reads it exactly once to lift the
    /// annotations out, and after that it stays on disk untouched as the only
    /// recovery path for reader data that has no upstream anywhere.
    static var legacyStoreURL: URL { groupURL.appending(path: "ACIMDailyMinute.sqlite") }

    static func makeContainer(allowsSave: Bool) throws -> ModelContainer {
        if !allowsSave { try createStoresIfMissing() }

        // ⛔ **Both configurations must be NAMED, and that is not cosmetic.**
        // Two unnamed configurations collapse onto the one default
        // configuration: every entity is registered against both stores, and the
        // first insert dies with the Objective-C exception "Can't assign an
        // object to a store that does not contain the object's entity." ⛔ That
        // is an `NSException`, not a Swift `Error`, so no `do`/`catch` anywhere
        // up the stack can see it — the app simply aborts at launch, inside the
        // container's own initializer, before a single view exists. Measured on
        // this Mac, twice: unnamed crashes, named partitions cleanly.
        let readerConfiguration = ModelConfiguration(
            "reader",
            schema: Schema(readerModels),
            url: readerStoreURL,
            allowsSave: allowsSave
        )
        let cacheConfiguration = ModelConfiguration(
            "cache",
            schema: Schema(cacheModels),
            url: cacheStoreURL,
            allowsSave: allowsSave
        )
        return try ModelContainer(
            for: Schema(readerModels + cacheModels),
            configurations: [readerConfiguration, cacheConfiguration]
        )
    }

    /// ⛔ **A read-only configuration cannot create a store it cannot find.** It
    /// throws `loadIssueModelContainer` — Core Data underneath reports "Attempt
    /// to open missing file read only" — and both read-only callers turn that
    /// into a hard failure: the widget extension `fatalError`s and the Shortcut
    /// throws. That is measured, not assumed.
    ///
    /// It matters because of *when* these two run. A widget redraws on the
    /// system's schedule, and after an update that lands this split there is a
    /// window where neither store exists yet because the app has not been opened
    /// once — which is precisely when a reader sees their home screen. So the
    /// read-only callers create the files first, writably, and then reopen them
    /// read-only. The files they create are empty and the app's migration fills
    /// the reader store afterwards regardless, since it is keyed on its own
    /// defaults flag and skips anything already present.
    private static func createStoresIfMissing() throws {
        let fileManager = FileManager.default
        let missing = [readerStoreURL, cacheStoreURL].contains {
            !fileManager.fileExists(atPath: $0.path)
        }
        guard missing else { return }
        _ = try makeContainer(allowsSave: true)
    }

    /// The widget extension's container. Read-only: a widget draws, it never
    /// writes.
    static let shared: ModelContainer = {
        do {
            return try makeContainer(allowsSave: false)
        } catch {
            fatalError("Could not create widget ModelContainer: \(error)")
        }
    }()
}

/// Lifts a reader's highlights, notes and bookmarks out of the pre-split store
/// and into `reader.store`, once.
///
/// ⛔ **The caches are not migrated and that is deliberate.** They re-derive from
/// the feed on the next fetch, and the saves that point into them survive it:
/// `ArchiveService.minuteLineHash(date:)` is a pure function of the date, so a
/// re-derived archive row lands on the same key the existing bookmark already
/// names. Annotations have no such upstream, which is the whole reason this
/// exists.
///
/// ⛔ **Opening the legacy file lightly migrates it** — its three unique indexes
/// drop, because the model classes no longer carry `@Attribute(.unique)`. That
/// is measured rather than assumed: a build with the attribute removed was run
/// against the real macOS App Group store, `Z_Bookmark_UNIQUE_itemKey`
/// disappeared, the schema opened without `fatalError`, every highlight and note
/// survived, and restoring the attribute rebuilt the index. Rows survive; only
/// the indexes go, and no row is ever written back.
enum ReaderStoreMigration {
    private static let didMigrateKey = "readerStoreMigrated"

    /// Idempotent twice over: the defaults flag skips the whole pass, and the
    /// copy itself skips anything the destination already holds. A migration
    /// that can only be run once is a migration that cannot be retried after a
    /// failure, and reader data is the wrong place to learn that.
    static func runIfNeeded(into container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didMigrateKey) else { return }

        let legacyURL = SharedModelContainer.legacyStoreURL
        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            // A fresh install has nothing to move.
            defaults.set(true, forKey: didMigrateKey)
            return
        }

        do {
            // The full nine-model schema, because the legacy file holds all
            // nine tables and describing it as anything less would invite
            // SwiftData to drop the ones left out — taking the recovery copy
            // with them.
            let legacySchema = Schema(
                SharedModelContainer.readerModels + SharedModelContainer.cacheModels
            )
            let legacyContainer = try ModelContainer(
                for: legacySchema,
                configurations: [ModelConfiguration(schema: legacySchema, url: legacyURL)]
            )
            let source = ModelContext(legacyContainer)
            let destination = ModelContext(container)

            try copyHighlights(from: source, to: destination)
            try copyNotes(from: source, to: destination)
            try copyBookmarks(from: source, to: destination)

            try destination.save()
            defaults.set(true, forKey: didMigrateKey)
        } catch {
            // Leave the flag clear and try again next launch. Nothing has been
            // removed from the legacy store, so there is always something to
            // retry from.
            //
            // ⛔ This catches Swift errors only. SwiftData's store-assignment
            // failures arrive as `NSException`s and are not catchable here at
            // all — they abort the process. So this is a retry path for a
            // transient failure, never a safety net for a wrong schema.
        }
    }

    private static func copyHighlights(from source: ModelContext, to destination: ModelContext) throws {
        var seen = Set(try destination.fetch(FetchDescriptor<Highlight>()).map(\.id))
        for row in try source.fetch(FetchDescriptor<Highlight>()) where seen.insert(row.id).inserted {
            let copy = Highlight()
            copy.id = row.id
            copy.readingKey = row.readingKey
            copy.startOffset = row.startOffset
            copy.length = row.length
            copy.quote = row.quote
            copy.createdAt = row.createdAt
            // `isOrphaned` is this device's verdict about its own corpus and is
            // re-derived by `AnnotationStore.reanchor` on the next read, but it
            // costs nothing to carry and avoids one pass of flicker.
            copy.isOrphaned = row.isOrphaned
            destination.insert(copy)
        }
    }

    private static func copyNotes(from source: ModelContext, to destination: ModelContext) throws {
        var seen = Set(try destination.fetch(FetchDescriptor<Note>()).map(\.id))
        for row in try source.fetch(FetchDescriptor<Note>()) where seen.insert(row.id).inserted {
            let copy = Note()
            copy.id = row.id
            copy.readingKey = row.readingKey
            copy.body = row.body
            copy.createdAt = row.createdAt
            copy.updatedAt = row.updatedAt
            copy.highlightID = row.highlightID
            destination.insert(copy)
        }
    }

    private static func copyBookmarks(from source: ModelContext, to destination: ModelContext) throws {
        var seen = Set(try destination.fetch(FetchDescriptor<Bookmark>()).map(\.itemKey))
        for row in try source.fetch(FetchDescriptor<Bookmark>()) where seen.insert(row.itemKey).inserted {
            let copy = Bookmark()
            copy.itemKey = row.itemKey
            copy.channel = row.channel
            copy.createdAt = row.createdAt
            destination.insert(copy)
        }
    }
}
