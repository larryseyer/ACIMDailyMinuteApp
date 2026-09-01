import SwiftUI

/// The one control for adding a reading to the Saved tab.
///
/// It used to be a bare `bookmark` glyph sitting in each card's action row,
/// below the entire reading — two screens down on a phone, unlabelled, beside
/// a share glyph. Testing found it unfindable: the save worked, but nobody
/// could tell it was there. So it says what it does, and the surfaces that use
/// it put it above the fold.
///
/// Shared rather than repeated: the same button appears on the Daily Minute
/// and Lesson cards, on archive entries, and on the lesson detail screen, and
/// four hand-rolled copies is how they drift apart.
struct SaveButton: View {
    let isSaved: Bool
    let action: () -> Void

    private static let accent = Color(red: 0.83, green: 0.69, blue: 0.22)

    var body: some View {
        Button(action: action) {
            Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                .font(.caption.weight(.medium))
                // ⛔ "Saved" is about 8pt wider than "Save", so this button grows
                // when it is tapped. Without this the header row could fit before
                // the save and wrap after it — the layout changing under the
                // reader's finger, as a result of their own tap.
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isSaved ? Self.accent : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSaved ? Self.accent.opacity(0.15) : Color.white.opacity(0.08),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        // The capsule renders at its natural size; the tap target is padded out
        // to the 44pt minimum so a near miss still saves rather than doing
        // nothing.
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(isSaved ? "Remove from Saved" : "Save")
    }
}

#Preview {
    VStack(spacing: 16) {
        SaveButton(isSaved: false, action: {})
        SaveButton(isSaved: true, action: {})
    }
    .padding()
    .background(Color(white: 0.11))
    .preferredColorScheme(.dark)
}
