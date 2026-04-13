import Foundation
import CryptoKit

/// SHA-256 truncated to a hex prefix, used as a stable content identifier.
///
/// The ACIM JSON endpoints don't ship a server-side hash, so the client computes
/// one to populate `DailyMinute.segmentHash`, `DailyLesson.segmentHash`, and
/// `ArchivedReading.lineHash`. Truncating to 16 hex chars (64 bits) gives more
/// than enough collision resistance for the modest row counts (<10⁶) the app
/// will ever see, while keeping `@Attribute(.unique)` index entries compact.
enum HashUtility {
    static func sha256Truncated(_ input: String, length: Int = 16) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(length))
    }
}
