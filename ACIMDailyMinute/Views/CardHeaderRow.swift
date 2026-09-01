import SwiftUI

/// The label-and-controls strip across the top of a reading card, and the one
/// place that decides what happens when it will not fit on a line.
///
/// ⛔ **It will not fit, on a real phone, today.** The card gives this row 303pt
/// on a 375pt canvas — which is what an iPhone 11 Pro Max reports while Display
/// Zoom is on — and a label plus Save, Share and Listen needs about 310pt once
/// the reader's text size reaches `xxLarge`. Before `audio_url` was filled in
/// there was no Listen button and the row fitted at every size, which is why
/// nothing had ever drawn it too narrow.
///
/// Given 7pt too little, SwiftUI squeezes whatever can be squeezed, and the only
/// squeezable things in the row are the two pieces of text. So both wrapped:
/// `DAILY MINUTE` broke across two lines and `Listen` hyphenated into `Lis-` and
/// `ten`. Nothing was clipped and nothing warned.
///
/// ⛔ **`lineLimit(1)` alone is not the fix** — it turns the wrap into `DAILY
/// MINU…`, which is worse, because the row still does not fit. The row has to
/// reflow: keep every control and every word, and take a second line when one
/// line cannot hold them. `ViewThatFits` picks the first candidate whose ideal
/// size fits, so the single row is used wherever it still can be and the phone
/// only ever sees two lines when it has to.
///
/// The label and the controls are deliberately non-shrinking, so a candidate is
/// measured at the width it actually wants rather than at the width it could be
/// crushed to — otherwise the one-line candidate always "fits" by wrapping, which
/// is the bug rather than the fix.
struct CardHeaderRow<Controls: View>: View {
    private let label: String
    private let controls: Controls

    init(_ label: String, @ViewBuilder controls: () -> Controls) {
        self.label = label
        self.controls = controls()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 4) {
                title
                Spacer(minLength: 4)
                controls
            }
            // The fallback. The label keeps the leading edge it has on one line,
            // and the controls stay right-aligned and in the same order, so a
            // reader who has seen the wide layout finds them where they were.
            VStack(alignment: .leading, spacing: 2) {
                title
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    controls
                }
            }
        }
    }

    private var title: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}
