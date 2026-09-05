#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import CoreGraphics
import Foundation

/// How tall a reading is when drawn at a given width.
///
/// Measured against a text container this function owns, rather than against
/// the one the view draws with. A view's container answers to the view: on
/// macOS `widthTracksTextView` slaves its width to the frame, so a width
/// assigned to it before the frame exists is discarded and the reading measures
/// zero — silently, because a collapsed measurement produces no error, just a
/// card with no room in it that the text then draws straight over.
///
/// ⛔ **Owning the container does not mean owning the engine.** Both reading
/// views draw with **TextKit 2** — a `UITextView` and an `NSTextView` created
/// with their plain initialisers both come up on `NSTextLayoutManager` — so the
/// measurement is TextKit 2 as well. Measuring with TextKit 1
/// (`NSLayoutManager.usedRect`) is short whenever the paragraph style carries a
/// non-zero `lineSpacing`, because the two engines put that spacing in
/// different places. At `lineSpacing: 0` they agree to the point; at the
/// `lineSpacing: 3` the five reading SCREENS pass, TextKit 1 measures about 7%
/// short on iOS and 2.5% on macOS, and the text view clips the tail of the
/// passage into a box too small for it.
///
/// ⛔ **Nothing about that failure looks like a failure.** No crash, no log, no
/// warning — the reading simply stops mid-sentence with `Add note` and the
/// citation drawn tidily beneath it, and there is nothing to scroll to. The
/// Today cards pass the default `lineSpacing: 0` and read whole, which is why
/// it survived so long. A new reading surface that wants line spacing inherits
/// the correct measurement automatically; one that reintroduces a TextKit 1
/// measurement fails `tools/verify_text_measurement.sh`, which now compares the
/// answer against a real text view.
///
/// Free of SwiftUI, SwiftData, `Bundle` and `CorpusService` on purpose:
/// `tools/verify_text_measurement.sh` compiles this file and nothing else, so
/// the same defect cannot return unseen on a platform nobody happened to open.
enum ReadingTextMeasurement {
    /// The height `attributed` occupies when laid out at `width`, rounded up to
    /// a whole point. Returns 0 only for a width that cannot be laid out in.
    static func height(of attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        guard width > 0, width < .greatestFiniteMagnitude else { return 0 }

        let content = NSTextContentStorage()
        content.attributedString = attributed

        let container = NSTextContainer(
            size: CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        // Matches the text views the readings draw through; without it every
        // measurement is inset from the layout it is measuring.
        container.lineFragmentPadding = 0

        let layout = NSTextLayoutManager()
        layout.textContainer = container
        content.addTextLayoutManager(layout)

        // TextKit 2 lays out what is asked for and nothing else, so a document
        // range is what makes this a measurement of the whole reading rather
        // than of its first screen. Measured on the largest body in the bundle
        // — 34,385 characters — it costs no more than the TextKit 1 rule it
        // replaces: 9.2ms against 9.9ms at 335pt.
        layout.ensureLayout(for: layout.documentRange)
        return ceil(layout.usageBoundsForTextContainer.maxY)
    }
}
