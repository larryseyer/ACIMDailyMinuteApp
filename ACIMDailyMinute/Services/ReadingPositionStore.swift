import Foundation

/// Where the reader's ribbons live: one per book, in `UserDefaults.standard`.
///
/// Kept beside `PlaybackHistory` rather than in SwiftData, for
/// `PlaybackHistory`'s reasons. A new `@Model` has to be added to the
/// `Schema` in *both* the app and the widget's `SharedModelContainer`, and a
/// mismatch there fails the shared container at launch — the widget has no use
/// for a ribbon, and no reason to carry the risk of one.
///
/// ⛔ `UserDefaults.standard`, not the App Group: every reader setting in this
/// app lives there, so the widget and the watch can see none of them and
/// CloudKit carries none of them either. The ribbon travels **only** in the
/// backup file, like the reminder times.
///
/// This file and `AnnotatableReadingText` are the only two that touch a ribbon.
/// The value, the book, the merge and the re-anchoring are all in
/// `ReadingPosition`, which `tools/verify_reading_position.sh` compiles alone.
///
/// ⛔ **THE TELEVISION KEEPS ITS RIBBON, AND THAT WAS DECIDED RATHER THAN
/// OVERLOOKED.** His call is that the TV app carries no annotation at all, and
/// highlights, notes and saves are gone from it. A ribbon is not in that set,
/// and the boundary is the code's own rather than a preference: it lives here
/// in `UserDefaults` beside the reminder times and the appearance, never in
/// SwiftData with the marks; it is never painted, never exported, and never
/// listed in the Saved tab; and `SelectableReadingText` says outright that a
/// reader's place is not a reader's mark. It is a pointer, not a record of
/// anything the reader made.
///
/// It also earns its place hardest on a television. Getting back to where you
/// stopped costs a scroll on a phone and a long press on a remote, and the
/// durability rule is satisfied rather than bent: a tvOS ribbon is device-local
/// (no iCloud there), and if the App Group container is purged the reader loses
/// a scroll position and not a word they wrote. Nothing of theirs is trapped on
/// the television, because nothing of theirs is on it.
enum ReadingPositionStore {
    /// Exposed so a view can bind an `@AppStorage` to the same key and be told
    /// when a ribbon moves; the accessors below stay the write path.
    static let defaultsKey = "readingPositions"

    static var entries: [String: ReadingPosition] {
        get { ReadingPosition.decode(UserDefaults.standard.data(forKey: defaultsKey) ?? Data()) }
        set { UserDefaults.standard.set(ReadingPosition.encode(newValue), forKey: defaultsKey) }
    }

    static func position(for book: ReadingPosition.Book) -> ReadingPosition? {
        entries[book.rawValue]
    }

    /// The ribbon for this reading, if the ribbon for its book is in it.
    ///
    /// A book holds one ribbon, so a reader who moved on to another section has
    /// no ribbon in the one they left — which is right: they are not there any
    /// more, and a screen that scrolled them to an old place inside a reading
    /// they navigated to deliberately would be fighting them.
    static func position(matching key: ReadingKey) -> ReadingPosition? {
        guard let book = ReadingPosition.book(for: key),
              let position = entries[book.rawValue],
              position.readingKey == key.rawValue
        else { return nil }
        return position
    }

    /// Moves this book's ribbon, leaving every other book's alone.
    static func record(_ position: ReadingPosition) {
        guard let book = position.book else { return }
        var current = entries
        current[book.rawValue] = position
        entries = current
    }

    /// Merges another device's ribbons in, keeping the later of each.
    static func merge(_ incoming: [String: ReadingPosition]) {
        entries = ReadingPosition.merged(entries, incoming)
    }
}
