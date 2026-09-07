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
///
/// Not on tvOS. A television reports `.regular` too, but that is the iPad's
/// answer to a different question: 672pt (portrait) and 1180pt (landscape)
/// both leave empty wings on a 1920pt screen. tvOS already draws at 10-foot
/// type; the clamp is what made a thin page. The television uses the screen,
/// and the surfaces' own padding is the inset.
///
/// The 672pt base is wrapped in `@ScaledMetric` so the readable column grows
/// proportionally with Dynamic Type — matching UIKit's `readableContentGuide`.
/// A narrow macOS window (down to the 420pt minWidth) shrinks naturally; the
/// clamp only visibly activates when the parent exceeds the scaled width.
struct ReadableContentWidthModifier: ViewModifier {
    #if !os(tvOS)
    @ScaledMetric private var maxReadableWidth: CGFloat = 672

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
    #endif

    func body(content: Content) -> some View {
        #if os(tvOS)
        content
            .frame(maxWidth: .infinity, alignment: .leading)
        #else
        content
            .frame(maxWidth: shouldClamp ? maxReadableWidth : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        #endif
    }
}

extension View {
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidthModifier())
    }
}
