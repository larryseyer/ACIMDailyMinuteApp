import SwiftUI

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

    /// `nil` means follow the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
