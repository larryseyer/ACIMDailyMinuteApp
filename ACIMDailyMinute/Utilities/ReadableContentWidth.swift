import SwiftUI

/// Clamps content to a comfortable reading column when the parent is wider
/// than the platform's column — the pure-SwiftUI equivalent of UIKit's
/// `UIView.readableContentGuide`.
///
/// Default on: macOS. A window is user-resizable up to screen width, and the
/// 672pt base is wrapped in `@ScaledMetric` so the column grows with
/// Dynamic Type. A narrow window (down to the 420pt minWidth) shrinks
/// naturally; the clamp only visibly activates when the parent exceeds
/// the scaled width.
///
/// Default off on iOS/iPadOS. The iPhone fills the parent. The iPad used
/// to fill the window too — 672pt left empty wings on a full-screen
/// canvas. The split view on iPad opts in via `clampsReadableColumn`,
/// because its parent is the detail column, not the window.
///
/// Not on tvOS. A television reports `.regular` too, but that is the iPad's
/// answer to a different question. tvOS already draws at 10-foot type; the
/// clamp is what made a thin page. The television uses the screen, and the
/// surfaces' own padding is the inset.
private struct ClampsReadableColumnKey: EnvironmentKey {
    static var defaultValue: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}

extension EnvironmentValues {
    /// When true, `readableContentWidth()` caps at the scaled 672pt column
    /// and centres the remainder. macOS defaults on; iOS defaults off so
    /// the phone and a full-window iPad probe keep filling the parent.
    var clampsReadableColumn: Bool {
        get { self[ClampsReadableColumnKey.self] }
        set { self[ClampsReadableColumnKey.self] = newValue }
    }
}

struct ReadableContentWidthModifier: ViewModifier {
    @Environment(\.clampsReadableColumn) private var clampsReadableColumn
    @ScaledMetric private var maxReadableWidth: CGFloat = 672

    func body(content: Content) -> some View {
        if clampsReadableColumn {
            clamped(content)
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func clamped(_ content: Content) -> some View {
        content
            .frame(maxWidth: maxReadableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension View {
    func readableContentWidth() -> some View {
        modifier(ReadableContentWidthModifier())
    }
}
