#if os(iOS)
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
/// Free of SwiftUI, SwiftData, `Bundle` and `CorpusService` on purpose:
/// `tools/verify_text_measurement.sh` compiles this file and nothing else, so
/// the same defect cannot return unseen on a platform nobody happened to open.
enum ReadingTextMeasurement {
    /// The height `attributed` occupies when laid out at `width`, rounded up to
    /// a whole point. Returns 0 only for a width that cannot be laid out in.
    static func height(of attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        guard width > 0, width < .greatestFiniteMagnitude else { return 0 }

        let storage = NSTextStorage(attributedString: attributed)
        let container = NSTextContainer(
            size: CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        // Matches the text views the readings draw through; without it every
        // measurement is inset from the layout it is measuring.
        container.lineFragmentPadding = 0
        let layout = NSLayoutManager()
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)

        layout.ensureLayout(for: container)
        return ceil(layout.usedRect(for: container).height)
    }
}
