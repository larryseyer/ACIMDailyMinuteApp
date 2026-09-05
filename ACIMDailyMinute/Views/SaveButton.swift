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

    private static let accent = Color.acimGold

    var body: some View {
        #if os(tvOS)
        // ⛔ **His call: the TV app carries no annotation at all, and a save is
        // annotation.** A bookmark is reader-created content, and a television
        // has no route to carry it off — no share sheet, no iCloud entitlement,
        // and an App Group container the system may purge. Inviting a reader to
        // make a mark that cannot leave the device is worse than not offering
        // the mark.
        //
        // Absent rather than disabled, exactly as `ShareButton` is: the branch
        // lives here so all nine call sites follow without an edit, and
        // `CardHeaderRow` is already agnostic to how many controls a slot holds
        // — `SegmentReadingView` passes one and `CorpusReadingCard` passes none.
        EmptyView()
        #else
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
                    isSaved ? Self.accent.opacity(0.15) : Color.acimChip,
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
        #endif
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
