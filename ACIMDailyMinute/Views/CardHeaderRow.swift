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
///
/// ⛔ **`lineLimit(1)` and `fixedSize` do not actually stop a label being
/// squeezed, and that was measured on the real controls.** At `accessibility3`
/// on his phone's 303pt card `Save` drew 99.5pt against a natural 150.5pt, and
/// at `accessibility5` it drew 56.5pt against 191.5pt. SwiftUI compresses the
/// label rather than overflowing, and nothing clips and nothing warns. So the
/// control band buys width the same way the title band does — by becoming two
/// bands — through `ViewThatFits`. Almost every reader sees the one-band form;
/// the fallback engages only where the row genuinely cannot hold three controls.
/// `tools/verify_card_header_dynamic_type.sh` holds it, at every text size, and
/// it has to run on an iOS simulator to do so: `dynamicTypeSize` does nothing
/// on macOS, so a sweep written against AppKit would pass without measuring.
struct CardHeaderRow<Leading: View, Trailing: View>: View {
    private let label: String
    private let leading: Leading
    private let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// ⛔ At the accessibility sizes the eyebrow is simply wider than the card,
    /// and no band can be bought to hold it: `WORKBOOK FOR STUDENTS` measures
    /// 569.5pt inside his phone's 303pt card at `accessibility5`. Held to one
    /// line with `fixedSize` it neither wraps nor shrinks — it draws straight
    /// past both edges and takes the whole block's width with it, which is what
    /// pushed `Save` outside the card. Wrapping is the one way out that keeps
    /// every word: it is what was rejected as `DAILY MINU…`, and that was
    /// TRUNCATION, not wrapping. Below the accessibility sizes nothing changes.
    private var eyebrowMayWrap: Bool { dynamicTypeSize.isAccessibilitySize }

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
                .lineLimit(eyebrowMayWrap ? nil : 1)
                .fixedSize(horizontal: !eyebrowMayWrap, vertical: false)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            ViewThatFits(in: .horizontal) {
                // One band, which is what almost every reader sees.
                HStack(spacing: 4) {
                    leading
                    Spacer(minLength: 4)
                    trailing
                }

                // ⛔ Two bands, once the reader's text size means three controls
                // cannot share a line. Buying width by adding a band is the same
                // trade the title band above already makes, and it is the only
                // one that costs no words: the play control keeps the leading
                // edge and Share and Save keep the trailing edge, so nothing
                // reorders — the block just grows downward.
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        leading
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        trailing
                    }
                }
            }
        }
    }
}
