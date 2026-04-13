import Foundation

/// User-defined phrases that trigger a local notification when they appear in
/// a newly fetched Daily Minute or Daily Lesson.
///
/// Stored in `UserDefaults` rather than SwiftData because the data is small,
/// app-local (not synced to the App Group), and read by the matcher on every
/// fetch — keeping it out of the model context avoids unnecessary `@Query`
/// invalidation on the SwiftUI side.
enum PhraseStorage {
    static let maxPhrases = 10

    /// User-supplied phrases (case-insensitive substring match).
    static var phrases: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "watchedPhrases"),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "watchedPhrases")
        }
    }

    /// itemKeys (`"minute:{hash}"` / `"lesson:{N}"`) that have already triggered
    /// a phrase-match notification and must not re-trigger.
    static var notifiedItemKeys: Set<String> {
        get {
            guard let data = UserDefaults.standard.data(forKey: "phraseNotifiedItemKeys"),
                  let decoded = try? JSONDecoder().decode(Set<String>.self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "phraseNotifiedItemKeys")
        }
    }
}
