import Foundation

/// Pulls the 11-character video ID out of the several URL shapes the feeds and
/// the publisher's own records use: `youtube.com/embed/ID`, `watch?v=ID`, and
/// `youtu.be/ID`.
///
/// Shared by `YouTubePlayerView` (which needs it to build an embed URL) and
/// `LiteYouTubeCard` (which needs it to build a thumbnail URL) so the two cannot
/// disagree about what a given feed link points at.
enum YouTubeID {
    /// A video id from whatever shape the feed stored: a watch URL, a
    /// youtu.be link, an embed URL, or the bare 11-character id itself.
    static func resolve(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let id = extract(from: trimmed) { return id }
        guard trimmed.count == 11 else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return trimmed
    }

    static func extract(from url: String) -> String? {
        if url.contains("youtube.com/embed/") {
            return normalise(url.components(separatedBy: "embed/").last?.components(separatedBy: "?").first)
        }
        if let range = url.range(of: "v=") {
            let start = range.upperBound
            let end = url[start...].firstIndex(of: "&") ?? url.endIndex
            return normalise(String(url[start..<end]))
        }
        if url.contains("youtu.be/") {
            return normalise(url.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first)
        }
        return nil
    }

    /// A playlist embed (`embed/videoseries?list=…`) parses to the literal
    /// "videoseries", which is not a video and has no thumbnail. Reject it here
    /// rather than letting callers request an image that will 404.
    private static func normalise(_ candidate: String?) -> String? {
        guard let candidate, !candidate.isEmpty, candidate != "videoseries" else { return nil }
        return candidate
    }
}
