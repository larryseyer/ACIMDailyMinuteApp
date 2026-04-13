import Foundation

/// Shared watch-term matching logic used by both the foreground refresh
/// (StoriesView) and the background refresh (BackgroundRefreshManager).
enum WatchedTermMatcher {

    struct Match: Sendable {
        let storyHash: String
        let fact: String
        let matchedTerm: String
    }

    /// Returns stories from `dtos` that match any watched term and have NOT
    /// already been notified (per `WatchedTermsStorage.notifiedHashes`).
    static func findNewMatches(in dtos: [StoryDTO]) -> [Match] {
        let terms = WatchedTermsStorage.terms
        guard !terms.isEmpty else { return [] }

        let previouslyNotified = WatchedTermsStorage.notifiedHashes
        let lowercasedTerms = terms.map { $0.lowercased() }

        return dtos.compactMap { story in
            guard !previouslyNotified.contains(story.hash) else { return nil }
            let lowFact = story.fact.lowercased()
            guard let term = lowercasedTerms.first(where: { lowFact.contains($0) })
            else { return nil }
            return Match(storyHash: story.hash, fact: story.fact, matchedTerm: term)
        }
    }

    /// Marks all supplied hashes as notified so they won't re-trigger.
    static func markAllNotified(hashes: Set<String>) {
        WatchedTermsStorage.notifiedHashes = hashes
    }
}
