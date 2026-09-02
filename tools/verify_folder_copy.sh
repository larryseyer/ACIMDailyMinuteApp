#!/bin/bash
# Proves the folder a reader chose keeps receiving their file, and never a
# broken one.
#
# What this guards is the third way a reader's work leaves the device: the same
# backup file, written by itself into a folder they picked once so their own
# Dropbox, Drive or Syncthing carries it. Nothing about that path is loud. A
# bookmark that stops resolving after the folder is renamed, a half-written file
# picked up by a sync client mid-write, a write that fails and takes the previous
# copy with it — each of these is found months later by someone opening the
# folder on the other machine and finding nothing they can use.
#
# ⛔ The compile line names TWO source files and no others. That is half the
# check: the folder code must stay free of SwiftData, SwiftUI, UserDefaults and
# Date(), or the only way to exercise a folder that has moved or a volume that
# refuses a write is by hand, on a machine set up to fail in exactly that way.
#
# It runs against a real directory on this Mac — real bookmarks, a real rename, a
# real chmod — because the behaviour under test is the file system's, and a
# stand-in for it would prove nothing.
#
#   ./tools/verify_folder_copy.sh
set -e
set -o pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
# A read-only folder is left behind on failure; put the permission back before
# the directory is removed so a failing run still cleans up after itself.
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

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

/// A fixed clock, so two runs write the same bytes.
func date(_ offset: Double) -> Date {
    Date(timeIntervalSinceReferenceDate: 780_000_000 + offset)
}

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let manager = FileManager.default

func makeFolder(_ name: String) -> URL {
    let url = root.appendingPathComponent(name, isDirectory: true)
    try! manager.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func entries(of folder: URL) -> [String] {
    ((try? manager.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
}

/// A real document, with real reader content, encoded by the real encoder.
let document = BackupDocument(
    exportedAt: date(0),
    editionNote: "A Course in Miracles, Sparkly Edition",
    highlights: [
        BackupDocument.Highlight(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            readingKey: "text:5.3",
            startOffset: 12,
            length: 40,
            quote: "The Holy Spirit is the Mediator between the interpretations of the ego",
            createdAt: date(10),
            reading: "Chapter 5 — The Mind of the Atonement",
            citation: "T-5.3.7"
        )
    ],
    notes: [
        BackupDocument.Note(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            readingKey: "lesson:1",
            body: "Nothing I see means anything — and that is the whole practice.",
            createdAt: date(20),
            updatedAt: date(30),
            highlightId: nil,
            reading: "Lesson 1"
        )
    ],
    bookmarks: [
        BackupDocument.Bookmark(
            itemKey: "lesson:1", channel: "lesson", createdAt: date(40), readingKey: "lesson:1"
        )
    ]
)
let bytes = try! BackupDocument.encode(document)
let name = FolderCopy.filename(deviceName: "Larry’s MacBook Pro")

// MARK: - The filename

check(name == "ACIM Daily Minute backup (Larry’s MacBook Pro).json", "filename: \(name)")
check(
    FolderCopy.filename(deviceName: "a/b:c\\d") == "ACIM Daily Minute backup (a-b-c-d).json",
    "separators are not filename characters: \(FolderCopy.filename(deviceName: "a/b:c\\d"))"
)
check(
    FolderCopy.filename(deviceName: "   ") == "ACIM Daily Minute backup.json",
    "a blank device name still names the file"
)
check(!FolderCopy.filename(deviceName: "x").contains("/"), "no separator survives")

// MARK: - A bookmark finds the folder again

let folder = makeFolder("Reader's Dropbox")
let bookmark = try! FolderCopy.bookmark(for: folder)
check(!bookmark.isEmpty, "bookmark has bytes")

let found = try! FolderCopy.resolve(bookmark)
check(
    found.url.standardizedFileURL.resolvingSymlinksInPath() == folder.standardizedFileURL.resolvingSymlinksInPath(),
    "bookmark resolves to the folder: \(found.url.path)"
)
check(found.refreshedBookmark == nil, "a folder that has not moved needs no refresh")

// MARK: - The file round trips and replaces itself

try! FolderCopy.write(bytes, named: name, into: found.url)
check(entries(of: folder) == [name], "exactly one file after the first write: \(entries(of: folder))")

let readBack = try! Data(contentsOf: folder.appendingPathComponent(name))
check(readBack == bytes, "bytes read back are the bytes written")
let decoded = try! BackupDocument.decode(readBack)
check(decoded.highlights.map(\.id) == document.highlights.map(\.id), "highlight survives")
check(decoded.notes.first?.body == document.notes.first?.body, "note body survives")
check(decoded.bookmarks.first?.itemKey == "lesson:1", "bookmark survives")

var later = document
later.notes[0].body += " Also: I can choose peace instead of this."
let laterBytes = try! BackupDocument.encode(later)
try! FolderCopy.write(laterBytes, named: name, into: found.url)
check(entries(of: folder) == [name], "a second write replaces, it does not accumulate: \(entries(of: folder))")
check(
    try! Data(contentsOf: folder.appendingPathComponent(name)) == laterBytes,
    "the second write is what the file now holds"
)

// MARK: - The folder moves

let moved = root.appendingPathComponent("Reader's Dropbox (renamed)", isDirectory: true)
try! manager.moveItem(at: folder, to: moved)
let afterMove = try! FolderCopy.resolve(bookmark)
check(
    afterMove.url.standardizedFileURL.resolvingSymlinksInPath() == moved.standardizedFileURL.resolvingSymlinksInPath(),
    "a renamed folder is found again: \(afterMove.url.path)"
)
try! FolderCopy.write(bytes, named: name, into: afterMove.url)
check(entries(of: moved) == [name], "the write lands in the folder's new place")
if let refreshed = afterMove.refreshedBookmark {
    let again = try! FolderCopy.resolve(refreshed)
    check(
        again.url.standardizedFileURL.resolvingSymlinksInPath() == moved.standardizedFileURL.resolvingSymlinksInPath(),
        "the refreshed bookmark resolves straight to the new place"
    )
    check(again.refreshedBookmark == nil, "and needs no further refresh")
}

// MARK: - The folder will not take a write

let previous = try! Data(contentsOf: moved.appendingPathComponent(name))
try! manager.setAttributes([.posixPermissions: 0o555], ofItemAtPath: moved.path)
var refused: FolderCopy.Failure?
do {
    try FolderCopy.write(laterBytes, named: name, into: afterMove.url)
} catch let failure as FolderCopy.Failure {
    refused = failure
} catch {
    check(false, "an unexpected error type: \(error)")
}
try! manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: moved.path)
if case .notWritable(let reason)? = refused {
    check(!reason.isEmpty, "the refusal says why")
} else {
    check(false, "a read-only folder is reported as not writable: \(String(describing: refused))")
}
check(entries(of: moved) == [name], "no temporary file is left behind: \(entries(of: moved))")
check(
    try! Data(contentsOf: moved.appendingPathComponent(name)) == previous,
    "the previous copy is byte for byte intact after a refused write"
)
check(refused?.errorDescription?.hasPrefix("The copy could not be written.") == true, "the sentence a reader sees")

// MARK: - The folder is gone

try! manager.removeItem(at: moved)
var missing: FolderCopy.Failure?
do {
    _ = try FolderCopy.resolve(bookmark)
} catch let failure as FolderCopy.Failure {
    missing = failure
} catch {
    check(false, "an unexpected error type: \(error)")
}
check(missing == .folderMissing, "a deleted folder resolves to folderMissing: \(String(describing: missing))")
check(
    missing?.errorDescription == "The folder can no longer be found. Choose it again.",
    "the sentence a reader sees when the folder is gone"
)

var writeToGone: FolderCopy.Failure?
do {
    try FolderCopy.write(bytes, named: name, into: moved)
} catch let failure as FolderCopy.Failure {
    writeToGone = failure
} catch {
    check(false, "an unexpected error type: \(error)")
}
check(writeToGone == .folderMissing, "a write into a deleted folder is folderMissing, not a crash")

// MARK: - A file where a folder should be

let file = root.appendingPathComponent("not-a-folder.txt")
try! Data("x".utf8).write(to: file)
let fileBookmark = try! FolderCopy.bookmark(for: file)
var notAFolder: FolderCopy.Failure?
do {
    _ = try FolderCopy.resolve(fileBookmark)
} catch let failure as FolderCopy.Failure {
    notAFolder = failure
} catch {
    check(false, "an unexpected error type: \(error)")
}
check(notAFolder == .folderMissing, "a bookmark to a plain file is refused as a folder")

var garbage: FolderCopy.Failure?
do {
    _ = try FolderCopy.resolve(Data("not a bookmark".utf8))
} catch let failure as FolderCopy.Failure {
    garbage = failure
} catch {
    check(false, "an unexpected error type: \(error)")
}
check(garbage == .folderMissing, "unreadable bookmark data is folderMissing, not a crash")

if failures == 0 {
    print("\(checks) checks, the folder keeps receiving the file and never a broken one")
    print("OK")
} else {
    print("\(failures) FAILURE(S) of \(checks) checks")
}
exit(failures == 0 ? 0 : 1)
SWIFT

swiftc -O \
    "$REPO/ACIMDailyMinute/Services/FolderCopy.swift" \
    "$REPO/ACIMDailyMinute/Services/BackupDocument.swift" \
    "$WORK/main.swift" \
    -o "$WORK/verify"

mkdir -p "$WORK/folders"
"$WORK/verify" "$WORK/folders"
