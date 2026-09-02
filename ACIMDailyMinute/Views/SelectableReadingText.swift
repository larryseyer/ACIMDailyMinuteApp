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
    /// The words to open on, if any. Painted in the accent colour rather than
    /// highlight yellow so the app's pointer is never mistaken for the reader's
    /// own mark, and scrolled into view once on first layout.
    var spotlight: ReadingSpotlight? = nil

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
        let display = ReadingText.displayString(from: raw)
        let spotlightRange = resolvedSpotlight(in: display)
        TextViewRepresentable(
            attributed: Self.attributed(
                raw: raw,
                design: design,
                lineSpacing: lineSpacing,
                highlightedRanges: paintedRanges,
                spotlightRange: spotlightRange
            ),
            display: display,
            menuActions: menuActions,
            spotlight: spotlightRange.flatMap { Self.utf16Range(of: $0, in: display) }
        )
    }

    /// The spotlight's words, found again in the string this view draws. An
    /// orphaned spotlight paints and scrolls nothing.
    private func resolvedSpotlight(in display: String) -> Range<Int>? {
        guard let spotlight else { return nil }
        switch AnchorResolver.resolve(
            startOffset: spotlight.startOffset,
            length: spotlight.length,
            quote: spotlight.quote,
            in: display
        ) {
        case .exact(let range), .moved(let range): return range
        case .orphaned: return nil
        }
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
        highlightedRanges: [Range<Int>] = [],
        spotlightRange: Range<Int>? = nil
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
        if let spotlightRange, let utf16Range = utf16Range(of: spotlightRange, in: display) {
            result.addAttribute(.backgroundColor, value: spotlightColor, range: utf16Range)
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

    /// The app's own pointer, and deliberately not the accent colour: this
    /// app's accent is gold and a highlight is yellow, so an accent wash would
    /// read as a second, slightly different mark of the reader's own — and on
    /// macOS the accent is whatever the user set in System Settings, which may
    /// be yellow outright. A fixed blue reads as neither the reader's mark nor
    /// the app's chrome.
    fileprivate static var spotlightColor: PlatformColor {
        PlatformColor.systemBlue.withAlphaComponent(0.22)
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
    let spotlight: NSRange?

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
        if let spotlight, context.coordinator.scrolledSpotlight != spotlight {
            context.coordinator.scrolledSpotlight = spotlight
            // Layout has not happened when this runs; the rect is asked for on
            // the next turn, and once more after that if the view was still
            // empty, which is what a cold push looks like.
            Self.scroll(view, to: spotlight, attempt: 0)
        }
    }

    /// Brings the spotlight into view by walking up to the SwiftUI `ScrollView`
    /// this text view already lives in, rather than scrolling itself — the text
    /// view has scrolling switched off, and a second scroller would break both.
    ///
    /// The rect comes from `firstRect(for:)` rather than the layout manager:
    /// touching `layoutManager` forces the view back onto TextKit 1.
    @MainActor
    private static func scroll(_ view: UITextView, to range: NSRange, attempt: Int) {
        Task { @MainActor in
            if attempt > 0 { try? await Task.sleep(nanoseconds: 150_000_000) }
            guard let start = view.position(from: view.beginningOfDocument, offset: range.location),
                  let end = view.position(from: start, offset: range.length),
                  let textRange = view.textRange(from: start, to: end)
            else { return }
            let rect = view.firstRect(for: textRange)
            var scrollView: UIScrollView?
            var candidate = view.superview
            while let current = candidate {
                if let found = current as? UIScrollView { scrollView = found; break }
                candidate = current.superview
            }
            guard let scrollView else { return }
            guard rect.height > 0, rect.height.isFinite, scrollView.bounds.height > 0 else {
                if attempt < 2 { scroll(view, to: range, attempt: attempt + 1) }
                return
            }
            let target = view.convert(rect, to: scrollView)
                .insetBy(dx: 0, dy: -scrollView.bounds.height / 3)
            scrollView.scrollRectToVisible(target, animated: false)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var display: String = ""
        var menuActions: [SelectableReadingText.MenuAction] = []
        /// What has already been scrolled to. The scroll happens once per
        /// spotlight; `updateUIView` runs on every redraw, and re-scrolling
        /// would drag the reader back here every time they moved.
        var scrolledSpotlight: NSRange?

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
        // Measured through `ReadingTextMeasurement` rather than the view, so both
        // platforms size a reading by the one rule `verify_text_measurement.sh`
        // compiles and checks.
        return CGSize(
            width: width,
            height: ReadingTextMeasurement.height(of: attributed, width: width)
        )
    }
}
#elseif os(macOS)
private struct TextViewRepresentable: NSViewRepresentable {
    let attributed: NSAttributedString
    let display: String
    let menuActions: [SelectableReadingText.MenuAction]
    let spotlight: NSRange?

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
        if let spotlight, context.coordinator.scrolledSpotlight != spotlight {
            context.coordinator.scrolledSpotlight = spotlight
            Self.scroll(view, to: spotlight, attempt: 0)
        }
    }

    /// The rect comes from `firstRect(forCharacterRange:actualRange:)` rather
    /// than the layout manager, which would force the view back onto TextKit 1.
    /// It arrives in screen coordinates, so it is converted back down through
    /// the window before the enclosing scroller is asked to show it.
    @MainActor
    private static func scroll(_ view: NSTextView, to range: NSRange, attempt: Int) {
        Task { @MainActor in
            if attempt > 0 { try? await Task.sleep(nanoseconds: 150_000_000) }
            guard let window = view.window else {
                if attempt < 2 { scroll(view, to: range, attempt: attempt + 1) }
                return
            }
            let screenRect = view.firstRect(forCharacterRange: range, actualRange: nil)
            let windowRect = window.convertFromScreen(screenRect)
            let local = view.convert(windowRect, from: nil)
            guard local.height > 0, local.height.isFinite else {
                if attempt < 2 { scroll(view, to: range, attempt: attempt + 1) }
                return
            }
            let visibleHeight = view.enclosingScrollView?.contentView.bounds.height ?? 400
            view.scrollToVisible(local.insetBy(dx: 0, dy: -visibleHeight / 3))
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var display: String = ""
        var menuActions: [SelectableReadingText.MenuAction] = []
        /// What has already been scrolled to. The scroll happens once per
        /// spotlight; `updateNSView` runs on every redraw, and re-scrolling
        /// would drag the reader back here every time they moved.
        var scrolledSpotlight: NSRange?
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
        guard let width = proposal.width, width > 0, width < .greatestFiniteMagnitude
        else { return nil }
        // ⛔ Never measure through `nsView`'s own container. `widthTracksTextView`
        // keeps that container's width equal to the view's frame width, so a
        // width assigned to it here is discarded and every reading measures
        // zero. The view keeps tracking — that is what makes it DRAW at the
        // width SwiftUI hands it — and measuring happens somewhere else.
        return CGSize(
            width: width,
            height: ReadingTextMeasurement.height(of: attributed, width: width)
        )
    }
}
#endif
