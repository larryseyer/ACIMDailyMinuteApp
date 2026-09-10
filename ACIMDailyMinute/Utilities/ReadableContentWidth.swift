import SwiftUI

/// Clamps content to a comfortable reading column when the parent is wider
/// than the platform's column — the pure-SwiftUI equivalent of UIKit's
/// `UIView.readableContentGuide`.
///
/// macOS only. A window is user-resizable up to screen width, and the
/// 672pt base is wrapped in `@ScaledMetric` so the column grows with
/// Dynamic Type. A narrow window (down to the 420pt minWidth) shrinks
/// naturally; the clamp only visibly activates when the parent exceeds
/// the scaled width.
///
/// Not on iOS/iPadOS. Regular size class is the iPad's full-width canvas,
/// and 672pt leaves empty wings — 74pt each side on 820pt portrait, 254pt
/// each side on 1180pt landscape. The iPad uses the screen; the surfaces'
/// own padding is the inset. Compact (iPhone, and iPad Slide Over / Split
/// View) already filled the parent.
///
/// Not on tvOS. A television reports `.regular` too, but that is the iPad's
/// answer to a different question. tvOS already draws at 10-foot type; the
/// clamp is what made a thin page. The television uses the screen, and the
/// surfaces' own padding is the inset.
struct ReadableContentWidthModifier: ViewModifier {
    #if os(macOS)
    @ScaledMetric private var maxReadableWidth: CGFloat = 672
    #endif

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .frame(maxWidth: maxReadableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        #else
        content
            .frame(maxWidth: .infinity, alignment: .leading)
        #endif
    }
}

extension View {
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidthModifier())
    }
}
