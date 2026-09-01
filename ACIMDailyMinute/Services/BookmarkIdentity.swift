import Foundation

/// What a bookmark write should do, decided over values rather than over a store.
///
/// `Bookmark.itemKey` is the only identity a bookmark has — there is no `id` — and
/// `@Attribute(.unique)` on it is currently the only thing preventing two rows from
/// naming the same passage. That constraint has to come off before SwiftData will
/// accept the store into a CloudKit container, so the invariant moves here first.
///
/// Deliberately free of SwiftData, SwiftUI, `Bundle` and `Date()`, so
/// `tools/verify_bookmark_identity.sh` can compile this file alone and drive the
/// rules directly. `BookmarkStore` is the thin shell that fetches rows, asks this
/// for a decision, and applies it.
enum BookmarkIdentity {

    /// A bookmark reduced to the two fields any decision here can depend on.
    struct Row: Equatable {
        var itemKey: String
        var createdAt: Date

        init(itemKey: String, createdAt: Date) {
            self.itemKey = itemKey
            self.createdAt = createdAt
        }
    }

    /// What a Save tap resolves to.
    enum ToggleAction: Equatable {
        case insert
        /// Every index holding the key, not the first one found.
        case delete([Int])
    }

    /// What re-keying a bookmark onto a new address resolves to.
    enum RenameAction: Equatable {
        case nothing
        /// Rewrite these rows' `itemKey`; nothing already holds the destination.
        case rename([Int])
        /// The destination is occupied. Keep the row at `keep` with `createdAt`,
        /// and delete the rest — a rename onto it would make two rows one key.
        case merge(keep: Int, createdAt: Date, delete: [Int])
    }

    /// Decide a Save tap.
    ///
    /// Returns *all* matching indices rather than one. A caller that deletes only
    /// the first leaves a duplicate behind, and the reader's un-save silently does
    /// nothing — which is the failure this whole type exists to make impossible.
    static func toggle(key: String, among rows: [Row]) -> ToggleAction {
        let matches = indices(of: key, in: rows)
        return matches.isEmpty ? .insert : .delete(matches)
    }

    /// Decide a re-key from one address to another.
    ///
    /// When both addresses are occupied the two rows are the same reader gesture
    /// recorded twice, so they fold into one. The survivor keeps the **earlier**
    /// `createdAt`: a bookmark records that a reader saved a passage, and the
    /// first time they did it is the true answer. `BackupMerge` folds two
    /// bookmarks the same direction, so a device and a backup file cannot disagree
    /// about which save was real.
    static func rename(_ from: String, to destination: String, among rows: [Row]) -> RenameAction {
        guard from != destination else { return .nothing }

        let moving = indices(of: from, in: rows)
        guard !moving.isEmpty else { return .nothing }

        let occupying = indices(of: destination, in: rows)
        guard !occupying.isEmpty else { return .rename(moving) }

        let candidates = occupying + moving
        guard let keep = candidates.min(by: { earlier($0, $1, in: rows) }) else { return .nothing }

        return .merge(
            keep: keep,
            createdAt: rows[keep].createdAt,
            delete: candidates.filter { $0 != keep }
        )
    }

    // MARK: - Private

    private static func indices(of key: String, in rows: [Row]) -> [Int] {
        rows.indices.filter { rows[$0].itemKey == key }
    }

    /// Ties break on position so the rule is a total order and cannot depend on
    /// the order a fetch happened to return rows in.
    private static func earlier(_ lhs: Int, _ rhs: Int, in rows: [Row]) -> Bool {
        let left = rows[lhs].createdAt
        let right = rows[rhs].createdAt
        return left == right ? lhs < rhs : left < right
    }
}
