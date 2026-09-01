import SwiftUI

/// The title-and-controls block at the top of a reading card.
///
/// Two bands, always: the title centred on its own line, and beneath it the
/// controls — the play control on the leading edge, Share and Save on the
/// trailing edge.
///
/// ⛔ **The play control is leftmost so that Share and Save never move.** Audio
/// and video are produced about one a day, so most readings carry neither and
/// this button is usually absent. Anchoring it to the leading edge means its
/// arrival pushes nothing: the two controls a reader uses on every passage stay
/// exactly where they were on the passage before.
///
/// ⛔ **One line was tried and does not fit.** A card gives this block 303pt on
/// a 375pt canvas — which is what an iPhone 11 Pro Max reports while Display Zoom
/// is on — and a label plus three controls needs about 310pt once the reader's
/// text size reaches `xxLarge`. Given 7pt too little, SwiftUI squeezes whatever
/// can be squeezed, and the only squeezable things are the words: `DAILY MINUTE`
/// broke across two lines and `Listen` hyphenated into `Lis-` and `ten`. Nothing
/// was clipped and nothing warned. Two bands are used on every size rather than
/// only where one line fails, so a card looks the same on a phone, a Mac and an
/// iPad instead of rearranging itself between them.
///
/// ⛔ **Nothing here is allowed to shrink or wrap.** `lineLimit(1)` on its own
/// would have turned the wrap into `DAILY MINU…`, which is worse; the width is
/// bought by the second band instead. `tools/verify_card_header.sh` holds it.
struct CardHeaderRow<Leading: View, Trailing: View>: View {
    private let label: String
    private let leading: Leading
    private let trailing: Trailing

    init(
        _ label: String,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.label = label
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 4) {
                leading
                Spacer(minLength: 4)
                trailing
            }
        }
    }
}
