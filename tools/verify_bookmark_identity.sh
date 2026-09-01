#!/bin/bash
# Proves a reader's Save is the only thing that decides whether a passage is saved.
#
# What this guards is the one field a bookmark has. `Bookmark` carries no `id` —
# `itemKey` IS its identity — and `@Attribute(.unique)` on it is the only thing
# standing between a reader and two rows naming one passage. SwiftData refuses
# that attribute in a CloudKit-backed store, so the invariant has to live in code
# before the index can come off. This is the code it lives in.
#
# Neither failure it guards is loud. A toggle that deletes the FIRST matching row
# leaves the second behind, so un-saving does nothing and the passage stays in
# Saved forever. A re-key that renames one row onto an address another row already
# holds makes two rows one key — today a rejected save that throws today's minute
# out of persistMinute, tomorrow a silent duplicate.
#
# ⛔ The compile line names ONE source file and no others. That is half the check:
# the rule must stay free of SwiftData, SwiftUI, Bundle and Date(), or it can only
# be exercised by running the app against a real store on a real device, which is
# where a duplicate bookmark is least visible and most permanent.
#
#   ./tools/verify_bookmark_identity.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/main.swift" <<'SWIFT'
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures = 0
var checks = 0

func check(_ condition: Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition {
        failures += 1
        if failures <= 20 { print("  \(message())") }
    }
}

/// A fixed clock. A rule that reaches for the wall clock cannot be checked twice
/// and get the same answer.
func date(_ offset: Double) -> Date {
    Date(timeIntervalSinceReferenceDate: 780_000_000 + offset)
}

typealias Row = BookmarkIdentity.Row

/// The store, as values. Mirrors what `BookmarkStore` does to a `ModelContext`.
func applyToggle(key: String, to rows: [Row], at now: Double) -> [Row] {
    switch BookmarkIdentity.toggle(key: key, among: rows) {
    case .insert:
        return rows + [Row(itemKey: key, createdAt: date(now))]
    case .delete(let indices):
        let doomed = Set(indices)
        return rows.indices.filter { !doomed.contains($0) }.map { rows[$0] }
    }
}

func applyRename(_ from: String, to destination: String, to rows: [Row]) -> [Row] {
    switch BookmarkIdentity.rename(from, to: destination, among: rows) {
    case .nothing:
        return rows
    case .rename(let indices):
        var out = rows
        for index in indices { out[index].itemKey = destination }
        return out
    case .merge(let keep, let createdAt, let delete):
        var out = rows
        out[keep].itemKey = destination
        out[keep].createdAt = createdAt
        let doomed = Set(delete)
        return out.indices.filter { !doomed.contains($0) }.map { out[$0] }
    }
}

func count(_ key: String, in rows: [Row]) -> Int {
    rows.filter { $0.itemKey == key }.count
}

// The real shapes every one of the six Save controls can emit, plus the archive
// scheme the migration re-keys away from.
let keys = [
    "minute:9f2a4c", "minute:0000ab", "lesson:1", "lesson:45", "lesson:365",
    "lesson:0", "lesson:500", "text:1.2", "text:16.2", "text:31.8", "manual:104",
]

// --- 1. Toggling is an involution, from every starting state ----------------
for key in keys {
    let empty: [Row] = []
    let saved = applyToggle(key: key, to: empty, at: 1)
    check(count(key, in: saved) == 1, "one toggle did not save \(key)")
    let unsaved = applyToggle(key: key, to: saved, at: 2)
    check(unsaved.isEmpty, "a second toggle did not un-save \(key)")
    let again = applyToggle(key: key, to: unsaved, at: 3)
    check(count(key, in: again) == 1, "a third toggle did not save \(key) again")
}

// --- 2. One un-save removes EVERY duplicate, not the first one --------------
// This is the failure the whole type exists for: `first(where:)` over a stale
// @Query snapshot leaves the second row, and the reader's tap does nothing.
for key in keys {
    for duplicates in 2...5 {
        var rows: [Row] = (0..<duplicates).map { Row(itemKey: key, createdAt: date(Double($0))) }
        rows.append(Row(itemKey: "lesson:999", createdAt: date(99)))
        let after = applyToggle(key: key, to: rows, at: 50)
        check(count(key, in: after) == 0,
              "un-saving \(key) left \(count(key, in: after)) of \(duplicates) rows")
        check(count("lesson:999", in: after) == 1,
              "un-saving \(key) disturbed an unrelated bookmark")
    }
}

// --- 3. Distinct keys are never confused ------------------------------------
let all = keys.enumerated().map { Row(itemKey: $1, createdAt: date(Double($0))) }
for key in keys {
    let after = applyToggle(key: key, to: all, at: 60)
    check(after.count == all.count - 1, "toggling \(key) changed more than one row")
    check(count(key, in: after) == 0, "toggling \(key) did not remove it")
    for other in keys where other != key {
        check(count(other, in: after) == 1, "toggling \(key) disturbed \(other)")
    }
}

// --- 4. Rename onto a free address just moves --------------------------------
let free = applyRename("minute:9f2a4c", to: "minute:stable1",
                       to: [Row(itemKey: "minute:9f2a4c", createdAt: date(10))])
check(count("minute:stable1", in: free) == 1, "a free rename did not move the row")
check(count("minute:9f2a4c", in: free) == 0, "a free rename left the old key behind")
check(free.first?.createdAt == date(10), "a free rename changed the reader's date")

// --- 5. Rename onto an occupied address folds, keeping the EARLIER date ------
// Several old-scheme archive rows for one date re-key to the same address, so
// this is reached in the field, not only in theory.
for (oldAt, newAt) in [(10.0, 20.0), (20.0, 10.0), (15.0, 15.0)] {
    let rows = [
        Row(itemKey: "minute:old", createdAt: date(oldAt)),
        Row(itemKey: "minute:new", createdAt: date(newAt)),
    ]
    let after = applyRename("minute:old", to: "minute:new", to: rows)
    check(after.count == 1, "a folding rename left \(after.count) rows, not 1")
    check(count("minute:new", in: after) == 1, "a folding rename lost the destination")
    check(after.first?.createdAt == date(min(oldAt, newAt)),
          "a fold kept \(after.first!.createdAt) rather than the earlier date")
}

// --- 6. A fold survives duplicates already present on both sides ------------
let messy = [
    Row(itemKey: "minute:old", createdAt: date(30)),
    Row(itemKey: "minute:old", createdAt: date(12)),
    Row(itemKey: "minute:new", createdAt: date(40)),
    Row(itemKey: "minute:new", createdAt: date(25)),
    Row(itemKey: "lesson:7", createdAt: date(99)),
]
let tidied = applyRename("minute:old", to: "minute:new", to: messy)
check(count("minute:new", in: tidied) == 1,
      "folding four rows left \(count("minute:new", in: tidied)), not 1")
check(count("minute:old", in: tidied) == 0, "folding left the old key behind")
check(count("lesson:7", in: tidied) == 1, "folding disturbed an unrelated bookmark")
check(tidied.first(where: { $0.itemKey == "minute:new" })?.createdAt == date(12),
      "folding did not keep the earliest of the four dates")

// --- 7. Both rules are idempotent -------------------------------------------
check(applyRename("minute:old", to: "minute:new", to: tidied) == tidied,
      "a second rename changed an already-renamed store")
check(applyRename("minute:new", to: "minute:new", to: tidied) == tidied,
      "renaming a key onto itself changed the store")
check(applyRename("minute:absent", to: "minute:new", to: tidied) == tidied,
      "renaming an absent key changed the store")

// --- 8. The fold agrees with BackupMerge over the same pairs ----------------
// BackupMerge takes the earlier createdAt when two bookmarks share a key
// (BackupMerge.swift:212-214). If these two rules ever disagreed, a device and
// the backup file it just wrote would name different saves as the real one.
for a in stride(from: 0.0, through: 40.0, by: 7.0) {
    for b in stride(from: 0.0, through: 40.0, by: 5.0) {
        let rows = [
            Row(itemKey: "k:1", createdAt: date(a)),
            Row(itemKey: "k:2", createdAt: date(b)),
        ]
        let folded = applyRename("k:1", to: "k:2", to: rows)
        check(folded.count == 1, "fold of (\(a), \(b)) left \(folded.count) rows")
        check(folded.first?.createdAt == date(min(a, b)),
              "fold of (\(a), \(b)) disagrees with BackupMerge's earlier-date rule")
    }
}

// --- 9. Order of a fetch cannot change the answer ---------------------------
let ordered = [
    Row(itemKey: "minute:new", createdAt: date(5)),
    Row(itemKey: "minute:old", createdAt: date(9)),
]
let reversed = Array(ordered.reversed())
let fromOrdered = applyRename("minute:old", to: "minute:new", to: ordered)
let fromReversed = applyRename("minute:old", to: "minute:new", to: reversed)
check(fromOrdered.map(\.createdAt) == fromReversed.map(\.createdAt),
      "the fold depends on the order the rows were fetched in")

if failures == 0 {
    print("\(checks) checks, a save is a save and two rows never name one passage")
    print("OK")
} else {
    print("\(failures) FAILURE(S) of \(checks) checks")
}
exit(failures == 0 ? 0 : 1)
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Services/BookmarkIdentity.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

"$WORK/verify"
