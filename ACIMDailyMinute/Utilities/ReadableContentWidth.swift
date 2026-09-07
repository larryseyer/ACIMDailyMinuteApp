import SwiftUI

/// Clamps content to a comfortable reading column when the parent is wider
/// than the platform's column — the pure-SwiftUI equivalent of UIKit's
/// `UIView.readableContentGuide`.
///
/// Engages when either:
/// - iOS/iPadOS `horizontalSizeClass == .regular` (iPad full-width; no-op on iPhone
///   and on iPad Slide Over / Split View compact slice)
/// - macOS (always — `horizontalSizeClass` is `nil` there, and the window is
///   user-resizable up to screen width)
/// - tvOS (always — a television reports `.regular` too, but that is the iPad's
///   answer to a different question, and must not select the iPad's column)
///
/// The base is wrapped in `@ScaledMetric` so the readable column grows
/// proportionally with Dynamic Type — matching UIKit's `readableContentGuide`.
/// A narrow macOS window (down to the 420pt minWidth) shrinks naturally; the
/// clamp only visibly activates when the parent exceeds the scaled width.
///
/// ⛔ **The television is not an iPad in portrait.** 672pt is the iPad's
/// portrait column, sized for 17pt body type. tvOS body type is already ~29pt
/// (a viewer eight to ten feet away), and a 4K Apple TV is 1920pt wide, so
/// handing it 672pt produces a thin portrait strip — 35% of the screen, lines
/// about half as long as the iPad's. The television uses the project's iPad
/// in landscape instead: 1180pt, the iPad (10th generation) landscape canvas.
/// That pair — landscape width, television type — is the same line length the
/// iPad already has, laid out as a landscape page rather than a portrait one.
struct ReadableContentWidthModifier: ViewModifier {
    #if os(tvOS)
    /// iPad (10th generation) landscape width, in points.
    @ScaledMetric private var maxReadableWidth: CGFloat = 1180
    #else
    @ScaledMetric private var maxReadableWidth: CGFloat = 672
    #endif

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var shouldClamp: Bool {
        #if os(iOS)
        return sizeClass == .regular
        #else
        return true
        #endif
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: shouldClamp ? maxReadableWidth : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension View {
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidthModifier())
    }
}
