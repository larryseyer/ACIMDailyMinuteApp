import Foundation
import SwiftData

/// Every write to a `Bookmark`, in one place, over the store rather than a snapshot.
///
/// The six Save controls used to decide whether a bookmark existed by searching
/// their own `@Query` array. That array is what the view last rendered, not what
/// the store holds: a row written by the watch, by an import, or by another
/// surface in the same tick is not in it yet. The view would then take the insert
/// branch, the unique index would reject the save, and `try? save()` would throw
/// the error away — the reader taps Save and nothing happens, silently.
///
/// So every decision here is made against a fetch. All the logic lives in
/// `BookmarkIdentity`, which is pure and checked by
/// `tools/verify_bookmark_identity.sh`; this type only fetches, applies and saves.
@MainActor
enum BookmarkStore {

    /// Save, or un-save, the passage at `key`.
    static func toggle(key: String, channel: String, in context: ModelContext) {
        let rows = fetch(key: key, in: context)

        switch BookmarkIdentity.toggle(key: key, among: rows.map(\.identity)) {
        case .insert:
            let bookmark = Bookmark()
            bookmark.itemKey = key
            bookmark.channel = channel
            bookmark.createdAt = Date()
            context.insert(bookmark)
        case .delete(let indices):
            for index in indices { context.delete(rows[index]) }
        }

        try? context.save()
    }

    /// Move any bookmark naming `from` onto `destination`.
    ///
    /// Used where a reading's identity is repaired and its saves have to follow.
    /// A plain rewrite is not enough: several rows can re-key onto one address, and
    /// renaming both would put two bookmarks on one key. Does not save — the
    /// migration that calls this saves once at the end of its own pass.
    static func resolveRename(from: String, to destination: String, in context: ModelContext) {
        let rows = fetch(keys: [from, destination], in: context)

        switch BookmarkIdentity.rename(from, to: destination, among: rows.map(\.identity)) {
        case .nothing:
            break
        case .rename(let indices):
            for index in indices { rows[index].itemKey = destination }
        case .merge(let keep, let createdAt, let delete):
            rows[keep].itemKey = destination
            rows[keep].createdAt = createdAt
            for index in delete { context.delete(rows[index]) }
        }
    }

    // MARK: - Private

    private static func fetch(key: String, in context: ModelContext) -> [Bookmark] {
        let wanted = key
        return (try? context.fetch(
            FetchDescriptor<Bookmark>(predicate: #Predicate { $0.itemKey == wanted })
        )) ?? []
    }

    private static func fetch(keys: [String], in context: ModelContext) -> [Bookmark] {
        let wanted = keys
        return (try? context.fetch(
            FetchDescriptor<Bookmark>(predicate: #Predicate { wanted.contains($0.itemKey) })
        )) ?? []
    }
}

private extension Bookmark {
    var identity: BookmarkIdentity.Row {
        .init(itemKey: itemKey, createdAt: createdAt)
    }
}
