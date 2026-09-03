import SwiftUI

/// The one control for playing a reading's narration.
///
/// Shared for the same reason `SaveButton` is: it was hand-rolled identically in
/// the Daily Minute card, the Lesson card and the archive card, and three copies
/// is how they drift apart. It also puts the no-wrapping guarantee in one place —
/// this label hyphenated into `Lis-` and `ten` on a real phone, and a fix applied
/// to two of three copies would have looked like a fix.
///
/// ⛔ **It says "Listen" rather than showing a bare ▶.** Dropping the word would
/// buy about 40pt and would have made the row fit on one line — but `SaveButton`
/// records that unlabelled glyphs tested as unfindable here, and buying width by
/// re-introducing a known usability defect is not a trade this app makes.
///
/// ⛔ **Absence is the normal state.** Audio and video are produced about one a
/// day, so most readings will carry neither for the life of this app. The caller
/// omits this button entirely rather than showing it disabled, and nothing else
/// in the row shifts position when one does appear.
struct ListenButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Listen", systemImage: "play.fill")
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.acimChip, in: Capsule())
        }
        .buttonStyle(.plain)
        // The capsule renders at its natural size; the tap target is padded out
        // to the 44pt minimum, as SaveButton's is.
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Listen to \(title)")
    }
}

#Preview {
    VStack(spacing: 16) {
        ListenButton(title: "Daily Minute", action: {})
        ListenButton(title: "Lesson 81", action: {})
    }
    .padding()
    .background(Color(white: 0.11))
    .preferredColorScheme(.dark)
}
