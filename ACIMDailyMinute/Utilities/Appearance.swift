import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// The reader's choice of appearance. Dark is the default because it is what
/// the app has always been.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let key = "appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Applies the choice at the window, which is the level that can take it
    /// back.
    ///
    /// ⛔ Not `preferredColorScheme`. Passing it `nil` after an explicit
    /// scheme does not undo that scheme: the window keeps the last one it was
    /// given, so Dark → Light → System left the reading card light while a
    /// sheet presented afterwards came up dark, because the sheet was a new
    /// window that asked the system. A window's own override, and on the Mac
    /// the app's appearance, reset to the system when cleared.
    @MainActor
    static func apply(_ raw: String) {
        let choice = Appearance(rawValue: raw) ?? .dark
        #if os(iOS)
        let style: UIUserInterfaceStyle = switch choice {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
        #elseif os(macOS)
        NSApp.appearance = switch choice {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
        #endif
    }
}
