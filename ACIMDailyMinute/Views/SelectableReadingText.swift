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
    /// Already re-anchored by `AnnotationStore.highlights(for:displayString:in:)`.
    var highlights: [Highlight] = []
    /// What the selection menu offers. Empty means nothing is added to the
    /// system menu at all, and the view is inert.
    var menuActions: [MenuAction] = []

    /// One item offered on a selection.
    ///
    /// The range it receives is in `Character` offsets. Converting from the text
    /// system's UTF-16 indices happens once, here, so no call site ever handles
    /// a UTF-16 index — a single accented character would otherwise shift every
    /// offset stored after it.
    struct MenuAction: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let handler: (Range<Int>, String) -> Void

        init(
            id: String,
            title: String,
            systemImage: String,
            handler: @escaping (Range<Int>, String) -> Void
        ) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.handler = handler
        }
    }

    var body: some View {
        TextViewRepresentable(
            attributed: Self.attributed(
                raw: raw,
                design: design,
                lineSpacing: lineSpacing,
                highlightedRanges: paintedRanges
            ),
            display: ReadingText.displayString(from: raw),
            menuActions: menuActions
        )
    }

    /// An orphaned highlight paints nothing: its stored offsets no longer point
    /// at its words, so any colour would land on the wrong sentence.
    private var paintedRanges: [Range<Int>] {
        highlights
            .filter { !$0.isOrphaned && $0.length > 0 }
            .map { $0.startOffset..<($0.startOffset + $0.length) }
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
    let display: String
    let menuActions: [SelectableReadingText.MenuAction]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
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
        context.coordinator.display = display
        context.coordinator.menuActions = menuActions
        if view.attributedText != attributed { view.attributedText = attributed }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var display: String = ""
        var menuActions: [SelectableReadingText.MenuAction] = []

        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            // Nil leaves the system menu exactly as it was, which is what keeps
            // a reading surface that offers no annotation completely unchanged.
            guard !menuActions.isEmpty, range.length > 0,
                  let characters = SelectableReadingText.characterRange(of: range, in: display)
            else { return nil }
            let quote = (display as NSString).substring(with: range)
            let added = menuActions.map { action in
                UIAction(title: action.title, image: UIImage(systemName: action.systemImage)) { _ in
                    action.handler(characters, quote)
                }
            }
            return UIMenu(children: suggestedActions + added)
        }
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
    let display: String
    let menuActions: [SelectableReadingText.MenuAction]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSTextView {
        let view = NSTextView()
        view.delegate = context.coordinator
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
        context.coordinator.display = display
        context.coordinator.menuActions = menuActions
        guard let storage = view.textStorage else { return }
        if !storage.isEqual(to: attributed) { storage.setAttributedString(attributed) }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var display: String = ""
        var menuActions: [SelectableReadingText.MenuAction] = []
        private weak var textView: NSTextView?

        func textView(
            _ view: NSTextView,
            menu: NSMenu,
            for event: NSEvent,
            at charIndex: Int
        ) -> NSMenu? {
            guard !menuActions.isEmpty, view.selectedRange().length > 0 else { return menu }
            textView = view
            for (index, action) in menuActions.enumerated() {
                let item = NSMenuItem(
                    title: action.title,
                    action: #selector(performMenuAction(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                menu.insertItem(item, at: index)
            }
            menu.insertItem(.separator(), at: menuActions.count)
            return menu
        }

        @objc private func performMenuAction(_ sender: NSMenuItem) {
            guard let textView, menuActions.indices.contains(sender.tag) else { return }
            let range = textView.selectedRange()
            guard range.length > 0,
                  let characters = SelectableReadingText.characterRange(of: range, in: display)
            else { return }
            menuActions[sender.tag].handler(
                characters, (display as NSString).substring(with: range)
            )
        }
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
