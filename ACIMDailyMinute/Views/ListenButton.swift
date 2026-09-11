import SwiftUI

/// The one control for playing a reading's narration.
///
/// Shared for the same reason `SaveButton` is: it was hand-rolled identically in
/// the Daily Minute card, the Lesson card and the archive card, and three copies
/// is how they drift apart. It also puts the no-wrapping guarantee in one place —
/// this label hyphenated into `Lis-` and `ten` on a real phone, and a fix applied
/// to two of three copies would have looked like a fix.
///
/// ⛔ **It says the word rather than showing a bare glyph.** Dropping it would
/// buy about 40pt and would have made the row fit on one line — but `SaveButton`
/// records that unlabelled glyphs tested as unfindable here, and buying width by
/// re-introducing a known usability defect is not a trade this app makes. While
/// this reading owns the mini player the control matches that bar: **Pause**
/// while playing, **Play** while paused, so the same finger that started
/// playback can halt it without reaching the bottom of the screen.
///
/// ⛔ **"Play" and "Pause" are not wider than "Listen".** The control is
/// leading-anchored, so a shorter capsule does not move Share and Save. Do not
/// reserve Listen's width — that would be buying space the trailing edge does
/// not need.
///
/// ⛔ **Absence is the normal state.** Audio and video are produced about one a
/// day, so most readings will carry neither for the life of this app. The caller
/// omits this button entirely rather than showing it disabled, and nothing else
/// in the row shifts position when one does appear.
struct ListenButton: View {
    enum Style {
        /// The chip on a card header.
        case chip
        /// Today's gold leading pill.
        case gold
    }

    let title: String
    var isActive: Bool = false
    var isPlaying: Bool = false
    var style: Style = .chip
    let action: () -> Void

    private var showsPause: Bool { isActive && isPlaying }

    private var label: String {
        if showsPause { return "Pause" }
        if isActive { return "Play" }
        return "Listen"
    }

    private var accessibilityText: String {
        if showsPause { return "Pause \(title)" }
        if isActive { return "Play \(title)" }
        return "Listen to \(title)"
    }

    var body: some View {
        Button(action: action) {
            Label(
                label,
                systemImage: showsPause ? "pause.fill" : "play.fill"
            )
                .font(style == .gold ? .acimChrome : .caption.weight(.medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(style == .gold ? Color.acimOnGold : Color.primary)
                .padding(.horizontal, style == .gold ? 14 : 10)
                .padding(.vertical, style == .gold ? 0 : 5)
                .frame(height: style == .gold ? 38 : nil)
                .background(style == .gold ? Color.acimGold : Color.acimChip, in: Capsule())
        }
        .buttonStyle(.plain)
        // The capsule renders at its natural size; the tap target is padded out
        // to the 44pt minimum, as SaveButton's is.
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityText)
    }
}

#Preview {
    VStack(spacing: 16) {
        ListenButton(title: "Daily Minute", action: {})
        ListenButton(title: "Daily Minute", isActive: true, isPlaying: true, action: {})
        ListenButton(title: "Daily Minute", isActive: true, isPlaying: false, action: {})
        ListenButton(title: "Lesson 81", action: {})
        ListenButton(title: "Lesson 81", isActive: true, isPlaying: true, action: {})
    }
    .padding()
    .background(Color(white: 0.11))
    .preferredColorScheme(.dark)
}
