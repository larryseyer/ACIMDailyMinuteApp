import SwiftUI

/// The one control for sharing a reading from a card header.
///
/// Shared for the reason `SaveButton` and `ListenButton` are: it was hand-rolled
/// identically on the Daily Minute, Lesson and Archive cards, and three copies
/// is how they drift apart. Here the drift was a platform: none of the three
/// set a button style, which iOS did not show because its default is
/// borderless, and macOS did — its default `ShareLink` draws a bordered well
/// the height of the card header, beside a Save capsule that draws its own.
///
/// `.plain` is what `SaveButton` and `ListenButton` already use; the glyph then
/// draws the same on every platform, and the 44pt frame keeps the tap target.
struct ShareButton: View {
    let text: String

    var body: some View {
        #if os(tvOS)
        // ⛔ tvOS has no share sheet, so the control is absent rather than
        // disabled — the same rule ListenButton follows for a reading with no
        // audio. CardHeaderRow's trailing edge simply carries one fewer item.
        EmptyView()
        #else
        ShareLink(item: text) {
            Image(systemName: "square.and.arrow.up")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share")
        #endif
    }
}

#Preview {
    HStack(spacing: 4) {
        ShareButton(text: "A passage.")
        SaveButton(isSaved: false, action: {})
    }
    .padding()
    .background(Color(white: 0.11))
    .preferredColorScheme(.dark)
}
