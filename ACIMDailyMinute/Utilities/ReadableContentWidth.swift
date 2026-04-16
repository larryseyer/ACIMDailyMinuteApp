import SwiftUI

/// Clamps content to a comfortable reading column when the parent is wider
/// than ~672pt — the pure-SwiftUI equivalent of UIKit's `UIView.readableContentGuide`.
///
/// Engages when either:
/// - iOS/iPadOS `horizontalSizeClass == .regular` (iPad full-width; no-op on iPhone
///   and on iPad Slide Over / Split View compact slice)
/// - macOS (always — `horizontalSizeClass` is `nil` there, and the window is
///   user-resizable up to screen width)
///
/// The 672pt base is wrapped in `@ScaledMetric` so the readable column grows
/// proportionally with Dynamic Type — matching UIKit's `readableContentGuide`.
/// A narrow macOS window (down to the 420pt minWidth) shrinks naturally; the
/// clamp only visibly activates when the parent exceeds the scaled width.
struct ReadableContentWidthModifier: ViewModifier {
    @ScaledMetric private var maxReadableWidth: CGFloat = 672

    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var shouldClamp: Bool {
        #if os(macOS)
        return true
        #else
        return sizeClass == .regular
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
