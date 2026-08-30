import SwiftUI

#if os(iOS)
import UIKit
private typealias PlatformFont = UIFont
private typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
private typealias PlatformFont = NSFont
private typealias PlatformColor = NSColor
#endif

/// Draws a reading through a platform text view instead of `Text`, so the words
/// can be selected and, later, marked.
///
/// The content is always `ReadingText.displayString(from:)` and never the raw
/// feed string. That is the whole point: highlight offsets are measured against
/// the same value the reader is looking at, and the two cannot drift apart
/// because there is only one of them.
///
/// Font and colour are parameters rather than SwiftUI modifiers. `.font()` and
/// `.foregroundStyle()` do nothing to a representable — they would read as
/// styling while changing nothing — so each call site states what it wants and
/// gets it.
struct SelectableReadingText: View {
    /// Which of the two type treatments the six reading surfaces use.
    enum Design {
        /// The serif body the Today cards and lesson detail read in.
        case serif
        /// The system body, used where a reading sits inside a denser screen.
        case standard
    }

    let raw: String
    var design: Design = .serif
    var lineSpacing: CGFloat = 0

    var body: some View {
        TextViewRepresentable(
            attributed: Self.attributed(raw: raw, design: design, lineSpacing: lineSpacing)
        )
    }

    /// The exact `NSAttributedString` the view draws, as a pure function.
    ///
    /// Kept free of any view so a harness can assert, against real bundled
    /// readings, that what would be drawn is character-for-character
    /// `ReadingText.displayString(from:)`.
    static func attributed(
        raw: String,
        design: Design = .serif,
        lineSpacing: CGFloat = 0,
        highlightedRanges: [Range<Int>] = []
    ) -> NSAttributedString {
        let display = ReadingText.displayString(from: raw)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing

        let result = NSMutableAttributedString(
            string: display,
            attributes: [
                .font: font(for: design),
                .foregroundColor: Self.bodyColor,
                .paragraphStyle: paragraph
            ]
        )

        // Ranges arrive as Character offsets into `display`; the attributed
        // string is indexed in UTF-16. Converting here, once, is what keeps a
        // single accented character from shifting every later mark.
        for range in highlightedRanges {
            guard let utf16Range = utf16Range(of: range, in: display) else { continue }
            result.addAttribute(.backgroundColor, value: highlightColor, range: utf16Range)
        }
        return result
    }

    /// Converts a `Character` range into the `NSRange` the text system needs.
    /// Returns nil rather than clamping: a range that does not fit is a range
    /// that was measured against a different string, and painting it anywhere
    /// would be worse than not painting it.
    static func utf16Range(of range: Range<Int>, in display: String) -> NSRange? {
        guard range.lowerBound >= 0, range.upperBound <= display.count else { return nil }
        let start = display.index(display.startIndex, offsetBy: range.lowerBound)
        let end = display.index(display.startIndex, offsetBy: range.upperBound)
        return NSRange(start..<end, in: display)
    }

    /// Converts a selection reported by the text view back into the `Character`
    /// offsets highlights are stored in.
    static func characterRange(of nsRange: NSRange, in display: String) -> Range<Int>? {
        guard let swiftRange = Range(nsRange, in: display) else { return nil }
        let start = display.distance(from: display.startIndex, to: swiftRange.lowerBound)
        let end = display.distance(from: display.startIndex, to: swiftRange.upperBound)
        return start..<end
    }

    fileprivate static var bodyColor: PlatformColor {
        #if os(iOS)
        .label
        #else
        .labelColor
        #endif
    }

    /// Deliberately translucent: a highlight sits behind the words, and the
    /// words have to stay readable in both appearances.
    fileprivate static var highlightColor: PlatformColor {
        PlatformColor.systemYellow.withAlphaComponent(0.28)
    }

    private static func font(for design: Design) -> PlatformFont {
        let base = PlatformFont.preferredFont(forTextStyle: .body)
        switch design {
        case .standard:
            return base
        case .serif:
            guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
            #if os(iOS)
            return PlatformFont(descriptor: descriptor, size: base.pointSize)
            #else
            return PlatformFont(descriptor: descriptor, size: base.pointSize) ?? base
            #endif
        }
    }
}

#if os(iOS)
private struct TextViewRepresentable: UIViewRepresentable {
    let attributed: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        // The call sites are already inside a SwiftUI ScrollView. A second
        // scroller here breaks both.
        view.isScrollEnabled = false
        view.isEditable = false
        view.isSelectable = true
        view.backgroundColor = .clear
        // Without these the text sits inset from the SwiftUI layout it replaces.
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.dataDetectorTypes = []
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.attributedText != attributed { view.attributedText = attributed }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width < .greatestFiniteMagnitude else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }
}
#elseif os(macOS)
private struct TextViewRepresentable: NSViewRepresentable {
    let attributed: NSAttributedString

    func makeNSView(context: Context) -> NSTextView {
        let view = NSTextView()
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.isAutomaticLinkDetectionEnabled = false
        return view
    }

    func updateNSView(_ view: NSTextView, context: Context) {
        guard let storage = view.textStorage else { return }
        if storage != attributed { storage.setAttributedString(attributed) }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width < .greatestFiniteMagnitude,
              let container = nsView.textContainer, let layout = nsView.layoutManager
        else { return nil }
        container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        return CGSize(width: width, height: ceil(layout.usedRect(for: container).height))
    }
}
#endif
