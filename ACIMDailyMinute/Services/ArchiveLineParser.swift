import Foundation
import CryptoKit

/// Parses the pipe-delimited archive text files served by www.acimdailyminute.org into
/// typed `ArchivedStory` instances.
///
/// # File format
///
/// Header lines begin with `#` and are skipped. Story lines have one of two shapes
/// depending on when the day was logged:
///
/// ```
/// timestamp | sources | ratings | urls | fact_text                     (5 columns — no audio)
/// timestamp | sources | ratings | urls | <hash>.mp3 | fact_text        (6 columns — with audio)
/// ```
///
/// The fact text is **always the last pipe-separated field**. Earlier fields carry
/// metadata whose count varies with format version. Locating the fact by
/// `parts.last` (rather than by a hard-coded index) is what makes the parser
/// resilient to past and future format shifts.
enum ArchiveLineParser {

    /// Parse an entire day's archive text into a list of `ArchivedStory` instances.
    ///
    /// Returned stories are **not** inserted into a SwiftData context — that's the
    /// caller's responsibility. This keeps the parser free of persistence concerns
    /// and easy to test.
    static func parse(rawText: String, dateString: String) -> [ArchivedStory] {
        let lines = rawText.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#")
        }
        return lines.compactMap { parseLine($0, dateString: dateString) }
    }

    /// Parse a single archive line. Returns `nil` if the line is malformed
    /// (fewer than 5 columns, or empty fact text).
    static func parseLine(_ line: String, dateString: String) -> ArchivedStory? {
        let parts = line.components(separatedBy: "|")
        // Need at least: timestamp | sources | ratings | urls | fact_text
        guard parts.count >= 5, let lastField = parts.last else { return nil }

        let factText = lastField.trimmingCharacters(in: .whitespaces)
        guard !factText.isEmpty else { return nil }

        // `ISO8601DateFormatter` is reference-type and not `Sendable` under Swift 6
        // strict concurrency, so we construct a fresh one per call rather than
        // caching a static singleton. Parsing cost is negligible at archive scale.
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = isoFormatter.date(from: parts[0])

        let sources = Self.splitCommaList(parts[1])
        let ratings = Self.splitCommaList(parts[2])

        // The URL field at parts[3] may contain a `[CORRECTED]` marker alongside
        // the actual URLs; pull the flag out and then extract only http(s) values.
        let urlField = parts[3]
        let isCorrected = urlField.contains("[CORRECTED]")
        let urls = urlField
            .replacingOccurrences(of: "[CORRECTED]", with: "")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("http") }

        // Audio column is optional. When present (6-column lines), it sits at
        // parts[4] as a hashed `.mp3` filename and the fact text moves to parts[5].
        // We already located the fact text as `parts.last`, so here we just check
        // whether parts[4] looks like an audio reference to preserve it.
        let audioFilename: String? = {
            guard parts.count >= 6 else { return nil }
            let candidate = parts[4].trimmingCharacters(in: .whitespaces)
            return candidate.hasSuffix(".mp3") ? candidate : nil
        }()

        let searchableText = ([factText] + sources + ratings).joined(separator: " ")

        let story = ArchivedStory()
        story.dateString = dateString
        story.timestamp = timestamp
        story.sources = sources
        story.ratings = ratings
        story.urls = urls
        story.audioFilename = audioFilename
        story.factText = factText
        story.searchableText = searchableText
        story.isCorrected = isCorrected
        story.lineHash = Self.stableHash(
            dateString: dateString,
            timestampField: parts[0],
            factText: factText
        )
        return story
    }

    // MARK: - Helpers

    private static func splitCommaList(_ field: String) -> [String] {
        field.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Deterministic 16-character content hash. Two stories with the same date,
    /// original timestamp field, and fact text will always share the same hash —
    /// which is exactly what SwiftData's `@Attribute(.unique)` needs to make
    /// re-ingestion idempotent.
    private static func stableHash(
        dateString: String,
        timestampField: String,
        factText: String
    ) -> String {
        let material = "\(dateString)|\(timestampField)|\(factText)"
        let digest = SHA256.hash(data: Data(material.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
