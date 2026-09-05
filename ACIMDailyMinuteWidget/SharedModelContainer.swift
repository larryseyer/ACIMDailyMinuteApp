import Foundation
import SwiftData
// Imported for its linker side effect as much as its API: macOS does not
// auto-link CloudKit the way iOS does, and the failure mode is sync that works
// in Debug and silently does nothing in a distributed build.
import CloudKit

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

    /// ⛔ **Not a force-unwrap any more, and the reason is tvOS.** A television's
    /// container — the App Group included — is *purgeable*: the system may
    /// reclaim it, and a target not provisioned with the group gets `nil` here.
    /// Force-unwrapping meant the app died at launch with a crash that named a
    /// URL rather than a missing entitlement.
    ///
    /// ⛔ **The fallback is not a second home for a reader's words.** On every
    /// platform that HAS the group this returns exactly what it always did, so
    /// nothing moves. Where the group is missing the app still opens and still
    /// reads — the bundle is permanent and the feed is re-fetchable — but nothing
    /// there may be treated as durable. That is the durability rule, not a
    /// convenience: on the TV the bundle and the feed are the only dependable
    /// sources, and a reader's own marks belong to CloudKit or to nothing.
    static var groupURL: URL {
        if let shared = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return shared
        }
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    static var readerStoreURL: URL { groupURL.appending(path: "reader.store") }
    static var cacheStoreURL: URL { groupURL.appending(path: "cache.store") }

    /// The single pre-split store. ⛔ **Never opened by `makeContainer`, and
    /// never deleted.** `ReaderStoreMigration` reads it exactly once to lift the
    /// annotations out, and after that it stays on disk untouched as the only
    /// recovery path for reader data that has no upstream anywhere.
    static var legacyStoreURL: URL { groupURL.appending(path: "ACIMDailyMinute.sqlite") }

    /// The reader's iCloud container. ⛔ Named explicitly rather than left to
    /// `.automatic`: `.automatic` picks from the entitlement's array, so if a
    /// second container ever appears there it would silently repoint and the
    /// reader's marks would land somewhere new.
    static let cloudKitContainerIdentifier = "iCloud.com.larryseyer.acimdailyminute"

    /// Whether the reader has asked for iCloud sync. **Off unless they say so.**
    ///
    /// ⛔ Plain `UserDefaults.standard`, and that is only correct because of the
    /// rule below: the app is the sole process that ever mirrors, so it is the
    /// sole process that needs this answer. An earlier design put the flag in the
    /// App Group so the widget could agree — which would have been the first
    /// `UserDefaults(suiteName:)` in the repo and, worse, unreliable on macOS,
    /// where this app is unsandboxed while its widget extension is sandboxed and
    /// the two resolve group preference domains differently.
    static var syncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: syncEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: syncEnabledKey) }
    }

    static let syncEnabledKey = "iCloudSyncEnabled"

    /// ⛔ **THE RULE: `allowsSave == false` ⇒ `cloudKitDatabase == .none`.**
    ///
    /// Only the app's one writable container mirrors, and only its reader
    /// configuration. Everything else — the widget, the Shortcut, the legacy
    /// store the migration reads — is structurally incapable of mirroring
    /// whatever the reader's setting says.
    ///
    /// Two failures this prevents, both documented rather than guessed:
    /// - Mirroring wants to *write* imported records, so a read-only store is the
    ///   wrong thing to hand it.
    /// - Two containers mirroring the same store **in one process** fail with
    ///   "CloudKit setup failed because there is another instance of this
    ///   persistent store actively syncing with CloudKit in this process." An App
    ///   Intent can run inside the app's process, and
    ///   `GetTodaysReadingIntent` builds its own container — so this is reachable
    ///   here, not theoretical.
    ///
    /// ⛔ And the trap underneath all of it: `cloudKitDatabase` defaults to
    /// **`.automatic`**, which means "mirror if the app is entitled to". Adding
    /// the iCloud entitlement would therefore have switched mirroring on for the
    /// cache store, the Shortcut and the legacy recovery copy, all by doing
    /// nothing. Every configuration in this file names its choice.
    static func makeContainer(allowsSave: Bool, includeReader: Bool = true) throws -> ModelContainer {
        if !allowsSave { try createStoresIfMissing() }

        let mirrorsReader = allowsSave && includeReader && syncEnabled

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
            allowsSave: allowsSave,
            cloudKitDatabase: mirrorsReader ? .private(cloudKitContainerIdentifier) : .none
        )
        // ⛔ `.none`, always and explicitly. The cache is the feed and the bundle
        // re-derived — megabytes of already-public text that would otherwise be
        // copied into the reader's iCloud for no purpose. Keeping it out is the
        // reason the store was split in the first place.
        let cacheConfiguration = ModelConfiguration(
            "cache",
            schema: Schema(cacheModels),
            url: cacheStoreURL,
            allowsSave: allowsSave,
            cloudKitDatabase: .none
        )

        guard includeReader else {
            return try ModelContainer(
                for: Schema(cacheModels),
                configurations: [cacheConfiguration]
            )
        }
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

    /// The widget extension's container. Read-only, so by the rule above it
    /// never mirrors and the widget target needs no iCloud entitlement.
    ///
    /// ⛔ Returns `nil` rather than `fatalError`ing. A blank widget beats a
    /// crashed one, and once CloudKit is anywhere near this store there are more
    /// ways for the open to fail than there were — none of which the reader can
    /// do anything about from their home screen.
    static let shared: ModelContainer? = {
        try? makeContainer(allowsSave: false)
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
            // ⛔ `.none` is the most important word in this function. This
            // configuration points at `ACIMDailyMinute.sqlite`, the only recovery
            // copy of data that has no upstream anywhere, and it carries all nine
            // models and all their unique constraints. Left at the default
            // `.automatic`, the arrival of the iCloud entitlement would have set
            // it mirroring.
            let legacyContainer = try ModelContainer(
                for: legacySchema,
                configurations: [ModelConfiguration(
                    schema: legacySchema,
                    url: legacyURL,
                    cloudKitDatabase: .none
                )]
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
