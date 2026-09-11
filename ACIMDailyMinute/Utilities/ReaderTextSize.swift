import Foundation
#if os(iOS)
import UIKit
#endif

/// The reader's choice of size for the serif body of a reading.
///
/// ⛔ **The body, and only the body.** Titles, captions, eyebrows and
/// chrome keep the system size. The number is a multiplier on
/// `preferredFont(.body)`, so Dynamic Type still moves the floor and
/// this choice scales it: Default is what the app has always drawn.
///
/// iPad defaults to Large because that screen has the room; iPhone and
/// Mac default to Default so nothing a reader has already seen changes
/// until they ask. Television does not offer the control and always
/// draws at 1.0.
enum ReaderTextSize: String, CaseIterable, Identifiable, Sendable {
    case `default` = "default"
    case large = "large"
    case larger = "larger"

    static let key = "readerTextSize"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .default: "Default"
        case .large: "Large"
        case .larger: "Larger"
        }
    }

    /// Applied to `preferredFont(.body).pointSize`. Default is 1.0 so the
    /// current drawing is the named choice, not an unnamed fourth size.
    var multiplier: CGFloat {
        switch self {
        case .default: 1.0
        case .large: 1.25
        case .larger: 1.5
        }
    }

    /// Fresh install. iPad starts at Large; everywhere else at Default.
    static var platformDefault: ReaderTextSize {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? .large : .default
        #else
        .default
        #endif
    }

    static func resolved(_ raw: String) -> ReaderTextSize {
        ReaderTextSize(rawValue: raw) ?? .default
    }

    static func scaledBodySize(base: CGFloat, raw: String) -> CGFloat {
        base * resolved(raw).multiplier
    }
}
