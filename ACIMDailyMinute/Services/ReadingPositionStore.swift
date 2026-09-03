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
