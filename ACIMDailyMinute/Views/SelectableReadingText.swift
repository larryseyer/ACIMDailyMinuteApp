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
    /// The words to open on, if any. Painted in a fixed blue, distinct from
    /// both the reader's own yellow highlight and the app's gold accent, and
    /// scrolled into view once on first layout.
    var spotlight: ReadingSpotlight? = nil
    /// Where the reader stopped last time, if this reading holds a ribbon.
    ///
    /// ⛔ Scrolled to and **never painted**. A reader's place is not a reader's
    /// mark: a wash here would read as a highlight they did not make, and the
    /// two would be indistinguishable on the page.
    var resume: ReadingPosition? = nil
    /// Filled in with a way to ask where the reader is now. See
    /// `PositionReporter`.
    var positionReporter: PositionReporter? = nil

    /// A way to ask the text view, later, which character is at the top of the
    /// screen.
    ///
    /// A box rather than a binding because the answer is wanted at one exact
    /// moment — the reading leaving the screen — and not continuously. Watching
    /// the scroll would mean a delegate on a scroll view this app does not own,
    /// and a write on every frame of a drag.
    ///
    /// ⛔ `currentOffset()` returning nil is ordinary, not an error: the text
    /// view may not be inside its scroller yet, or may not have been laid out.
    /// The caller records the reading anyway, at its top. **The reading is the
    /// durable part; the offset is the refinement.**
    @MainActor
    final class PositionReporter {
        fileprivate var read: (() -> Int?)?

        func currentOffset() -> Int? { read?() }
    }

    /// Where a tapped cross-reference goes. Installed by the enclosing stack's
    /// `readingDestinations(path:)`.
    @Environment(\.openReading) private var openReading

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
        let links = CrossReference.lessonReferences(in: display)
            .map { (range: $0.range, url: CrossReference.url(forLesson: $0.lesson)) }
        TextViewRepresentable(
            attributed: Self.attributed(
                raw: raw,
                design: design,
                lineSpacing: lineSpacing,
                highlightedRanges: paintedRanges,
                spotlightRange: spotlightRange,
                links: links
            ),
            display: display,
            menuActions: menuActions,
            spotlight: spotlightRange.flatMap { Self.utf16Range(of: $0, in: display) },
            // A spotlight wins over a ribbon: arriving on a search hit is a
            // request for those words, and scrolling somewhere else instead
            // would answer a question the reader did not ask.
            resume: spotlightRange == nil ? resumeRange(in: display) : nil,
            positionReporter: positionReporter,
            openLink: { url in
                // Following a reference from inside a reading is a request to
                // read the lesson it names, not to watch it.
                guard let lesson = CrossReference.lesson(from: url) else { return }
                openReading(.lesson(LessonRef(lessonNumber: lesson, presentsVideo: false)))
            }
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

    /// The ribbon as a range the text system can be asked for a rectangle of.
    ///
    /// One character rather than an empty range: `firstRect(for:)` of an empty
    /// range is not reliably a line, and a rectangle of no height is one of the
    /// two things the scroll walk already gives up on. A reading whose ribbon
    /// sits at its very top needs no scroll at all.
    private func resumeRange(in display: String) -> NSRange? {
        guard let resume else { return nil }
        let offset = resume.offset(in: display)
        guard offset > 0, offset < display.count else { return nil }
        return Self.utf16Range(of: offset..<(offset + 1), in: display)
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
        spotlightRange: Range<Int>? = nil,
        links: [(range: Range<Int>, url: URL)] = []
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
        // A link is a foreground attribute, so a highlight or a spotlight over
        // it still paints its background and the link still answers a tap.
        for link in links {
            guard let utf16Range = utf16Range(of: link.range, in: display) else { continue }
            result.addAttribute(.link, value: link.url, range: utf16Range)
        }
        return result
    }

    /// How long to keep asking for a rectangle that is not there yet.
    ///
    /// ⛔ Measured, not guessed. With three attempts 150ms apart, a pushed
    /// reading on this Mac never once had a window and a laid-out line in time,
    /// and the scroll then silently did nothing — which looks exactly like a
    /// spotlight or a ribbon that was never set, and is why a search hit and a
    /// resumed reading both landed at the top of the passage. A push animation,
    /// a first layout and a text container sizing itself all happen before there
    /// is a rectangle to convert. Twelve attempts 100ms apart is a little over a
    /// second, and every one of them returns the moment it succeeds.
    static let scrollAttempts = 12
    static let scrollRetryDelay: UInt64 = 100_000_000
    /// A resumed line sits a little below the top edge rather than flush against
    /// it, so it reads as the next thing rather than as a cut-off one.
    static let resumeTopMargin: CGFloat = 8

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

    /// The platform's own interactive-text colour, with no underline: the
    /// reference reads as the app's chrome and not as a web link. On macOS
    /// that is whatever accent the reader chose, which is what every other
    /// control in the window already wears.
    fileprivate static var linkAttributes: [NSAttributedString.Key: Any] {
        #if os(iOS)
        [.foregroundColor: PlatformColor.tintColor, .underlineStyle: 0]
        #else
        [.foregroundColor: PlatformColor.controlAccentColor, .underlineStyle: 0]
        #endif
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
    let resume: NSRange?
    let positionReporter: SelectableReadingText.PositionReporter?
    let openLink: (URL) -> Void

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
        view.linkTextAttributes = SelectableReadingText.linkAttributes
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.display = display
        context.coordinator.menuActions = menuActions
        context.coordinator.openLink = openLink
        if view.attributedText != attributed { view.attributedText = attributed }
        if let spotlight, context.coordinator.scrolledSpotlight != spotlight {
            context.coordinator.scrolledSpotlight = spotlight
            // Layout has not happened when this runs; the rect is asked for on
            // the next turn, and retried up to twice more if the text view is
            // not yet inside the SwiftUI scroll view or the rect is still
            // empty, either of which is what a cold push looks like.
            Self.scroll(view, to: spotlight, anchor: .spotlight, attempt: 0)
        }
        if let resume, context.coordinator.scrolledResume != resume {
            context.coordinator.scrolledResume = resume
            Self.scroll(view, to: resume, anchor: .top, attempt: 0)
        }
        installReporter(on: view, display: display)
    }

    /// Hands the owner a way to ask where the reader is now.
    ///
    /// The closure holds the view weakly and reads nothing until it is called,
    /// so nothing here runs during a scroll.
    private func installReporter(on view: UITextView, display: String) {
        guard let positionReporter else { return }
        positionReporter.read = { [weak view] in
            guard let view else { return nil }
            var scrollView: UIScrollView?
            var candidate = view.superview
            while let current = candidate {
                if let found = current as? UIScrollView { scrollView = found; break }
                candidate = current.superview
            }
            guard let scrollView, scrollView.bounds.height > 0 else { return nil }
            let top = CGPoint(
                x: 0, y: scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            )
            let local = scrollView.convert(top, to: view)
            // Above the reading is its beginning; below it, the reader has
            // scrolled past the whole passage and there is no place in it to
            // report.
            guard local.y > 0 else { return 0 }
            guard local.y < view.bounds.height else { return nil }
            guard let position = view.closestPosition(to: CGPoint(x: 0, y: local.y)) else {
                return nil
            }
            let utf16 = view.offset(from: view.beginningOfDocument, to: position)
            return SelectableReadingText.characterRange(
                of: NSRange(location: utf16, length: 0), in: display
            )?.lowerBound
        }
    }

    /// Brings the spotlight into view by walking up to the SwiftUI `ScrollView`
    /// this text view already lives in, rather than scrolling itself — the text
    /// view has scrolling switched off, and a second scroller would break both.
    ///
    /// Where in the viewport the range should land.
    ///
    /// A spotlight wants to be *seen*, so it is brought in with room around it
    /// and the reader keeps whatever context they had. A ribbon wants to be
    /// **at the top**: it is where reading resumes, and everything above it has
    /// already been read, so its offset is set on the scroller directly rather
    /// than asked for as "make this visible", which stops as soon as the line is
    /// on screen anywhere — including one pixel inside the bottom edge.
    enum ScrollAnchor {
        case spotlight
        case top
    }

    /// The rectangle a range occupies in the text view's own coordinates, with
    /// its line laid out first.
    ///
    /// ⛔ **TextKit 2 lays out what is on screen and nothing else**, so asking
    /// for the rectangle of a passage below the fold returns a rectangle of zero
    /// height — which is exactly the shape of "not there yet", and is what the
    /// retry loop then spent a second failing to distinguish. `ensureLayout`
    /// is the difference between a search hit near the top of a section working
    /// and the same hit two screens down doing nothing at all.
    ///
    /// It goes through `textLayoutManager` rather than `layoutManager`, which
    /// would force the view back onto TextKit 1, and the segment frame arrives
    /// in the text container's space — the container sits at the view's origin
    /// here, because the call site zeroes both the inset and the line padding.
    @MainActor
    private static func laidOutRect(of range: NSRange, in view: UITextView) -> CGRect? {
        guard let layout = view.textLayoutManager,
              let content = layout.textContentManager,
              let start = content.location(content.documentRange.location, offsetBy: range.location),
              let end = content.location(start, offsetBy: max(range.length, 1)),
              let textRange = NSTextRange(location: start, end: end)
        else { return nil }
        layout.ensureLayout(for: textRange)
        var found: CGRect?
        layout.enumerateTextSegments(in: textRange, type: .standard, options: []) { _, frame, _, _ in
            found = frame
            return false
        }
        return found
    }

    @MainActor
    private static func scroll(
        _ view: UITextView, to range: NSRange, anchor: ScrollAnchor, attempt: Int
    ) {
        Task { @MainActor in
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: SelectableReadingText.scrollRetryDelay)
            }
            let rect = laidOutRect(of: range, in: view) ?? .zero
            var scrollView: UIScrollView?
            var candidate = view.superview
            while let current = candidate {
                if let found = current as? UIScrollView { scrollView = found; break }
                candidate = current.superview
            }
            guard let scrollView else {
                if attempt < SelectableReadingText.scrollAttempts {
                    scroll(view, to: range, anchor: anchor, attempt: attempt + 1)
                }
                return
            }
            guard rect.height > 0, rect.height.isFinite, scrollView.bounds.height > 0 else {
                if attempt < SelectableReadingText.scrollAttempts {
                    scroll(view, to: range, anchor: anchor, attempt: attempt + 1)
                }
                return
            }
            let converted = view.convert(rect, to: scrollView)
            switch anchor {
            case .spotlight:
                scrollView.scrollRectToVisible(
                    converted.insetBy(dx: 0, dy: -scrollView.bounds.height / 3), animated: false
                )
            case .top:
                // A rect a whole viewport tall, hung from the line: it cannot
                // fit, so the scroller aligns its top edge rather than nudging
                // the line barely into view at the bottom.
                //
                // ⛔ Asked of the scroller, never set as a `contentOffset`. This
                // scroll view belongs to a SwiftUI `ScrollView`, which keeps its
                // own idea of where it is, and moving it underneath leaves the
                // bands laid out at the old offset and the body drawn at the new
                // one, one on top of the other.
                scrollView.scrollRectToVisible(
                    CGRect(
                        x: converted.minX,
                        y: converted.minY - SelectableReadingText.resumeTopMargin,
                        width: converted.width,
                        height: scrollView.bounds.height
                    ),
                    animated: false
                )
            }
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
        /// The same, for the ribbon — and it matters more here, because the
        /// reader's own scrolling is what moves it. Without this, resuming a
        /// reading would pin them to where they came back to and they could
        /// never leave it.
        var scrolledResume: NSRange?
        var openLink: (URL) -> Void = { _ in }

        /// A tap on a reference opens the lesson in this app. The default
        /// action would hand the URL to the system, which has nothing
        /// registered for it and would open nothing.
        func textView(
            _ textView: UITextView,
            primaryActionFor textItem: UITextItem,
            defaultAction: UIAction
        ) -> UIAction? {
            guard case .link(let url) = textItem.content else { return defaultAction }
            return UIAction { [openLink] _ in openLink(url) }
        }

        /// No preview and no share sheet on a long press: the URL is private
        /// to this app and would read as gibberish.
        func textView(
            _ textView: UITextView,
            menuConfigurationFor textItem: UITextItem,
            defaultMenu: UIMenu
        ) -> UITextItem.MenuConfiguration? {
            nil
        }


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
    let resume: NSRange?
    let positionReporter: SelectableReadingText.PositionReporter?
    let openLink: (URL) -> Void

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
        view.linkTextAttributes = SelectableReadingText.linkAttributes
        return view
    }

    func updateNSView(_ view: NSTextView, context: Context) {
        context.coordinator.display = display
        context.coordinator.menuActions = menuActions
        context.coordinator.openLink = openLink
        guard let storage = view.textStorage else { return }
        if !storage.isEqual(to: attributed) { storage.setAttributedString(attributed) }
        if let spotlight, context.coordinator.scrolledSpotlight != spotlight {
            context.coordinator.scrolledSpotlight = spotlight
            Self.scroll(view, to: spotlight, anchor: .spotlight, attempt: 0)
        }
        if let resume, context.coordinator.scrolledResume != resume {
            context.coordinator.scrolledResume = resume
            Self.scroll(view, to: resume, anchor: .top, attempt: 0)
        }
        installReporter(on: view, display: display)
    }

    /// Hands the owner a way to ask where the reader is now. See the iOS half:
    /// the answer is wanted once, when the reading leaves the screen.
    private func installReporter(on view: NSTextView, display: String) {
        guard let positionReporter else { return }
        positionReporter.read = { [weak view] in
            guard let view else { return nil }
            let visible = view.visibleRect
            guard visible.height > 0 else { return nil }
            guard visible.minY > 0 else { return 0 }
            guard visible.minY < view.bounds.height else { return nil }
            let utf16 = view.characterIndexForInsertion(
                at: CGPoint(x: visible.minX, y: visible.minY)
            )
            return SelectableReadingText.characterRange(
                of: NSRange(location: utf16, length: 0), in: display
            )?.lowerBound
        }
    }

    /// See the iOS half: a spotlight is brought in with room around it, a ribbon
    /// is put at the top, and the difference is one rectangle.
    enum ScrollAnchor {
        case spotlight
        case top
    }

    /// See the iOS half: TextKit 2 lays out only what is on screen, so a passage
    /// below the fold has no rectangle until `ensureLayout` is asked for one.
    @MainActor
    private static func laidOutRect(of range: NSRange, in view: NSTextView) -> CGRect? {
        guard let layout = view.textLayoutManager,
              let content = layout.textContentManager,
              let start = content.location(content.documentRange.location, offsetBy: range.location),
              let end = content.location(start, offsetBy: max(range.length, 1)),
              let textRange = NSTextRange(location: start, end: end)
        else { return nil }
        layout.ensureLayout(for: textRange)
        var found: CGRect?
        layout.enumerateTextSegments(in: textRange, type: .standard, options: []) { _, frame, _, _ in
            found = frame
            return false
        }
        guard var rect = found else { return nil }
        let origin = view.textContainerOrigin
        rect.origin.x += origin.x
        rect.origin.y += origin.y
        return rect
    }

    @MainActor
    private static func scroll(
        _ view: NSTextView, to range: NSRange, anchor: ScrollAnchor, attempt: Int
    ) {
        Task { @MainActor in
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: SelectableReadingText.scrollRetryDelay)
            }
            guard view.window != nil,
                  let scrollView = view.enclosingScrollView,
                  scrollView.contentView.bounds.height > 0
            else {
                if attempt < SelectableReadingText.scrollAttempts {
                    scroll(view, to: range, anchor: anchor, attempt: attempt + 1)
                }
                return
            }
            let local = laidOutRect(of: range, in: view) ?? .zero
            guard local.height > 0, local.height.isFinite else {
                if attempt < SelectableReadingText.scrollAttempts {
                    scroll(view, to: range, anchor: anchor, attempt: attempt + 1)
                }
                return
            }
            let viewport = scrollView.contentView.bounds.height
            switch anchor {
            case .spotlight:
                view.scrollToVisible(local.insetBy(dx: 0, dy: -viewport / 3))
            case .top:
                // A rect a whole viewport tall, hung from the line: it cannot
                // fit, so the scroller aligns its top edge instead of nudging
                // the line barely into view at the bottom.
                //
                // ⛔ Asked of the scroller, never set on the clip view. This
                // `NSScrollView` belongs to a SwiftUI `ScrollView`, which keeps
                // its own idea of where it is: moving the clip under it leaves
                // the bands laid out at the old offset and the body drawn at the
                // new one, one on top of the other.
                view.scrollToVisible(
                    CGRect(
                        x: local.minX,
                        y: max(0, local.minY - SelectableReadingText.resumeTopMargin),
                        width: local.width,
                        height: viewport
                    )
                )
            }
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
        /// The same, for the ribbon — and it matters more here, because the
        /// reader's own scrolling is what moves it.
        var scrolledResume: NSRange?
        private weak var textView: NSTextView?
        var openLink: (URL) -> Void = { _ in }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL else { return false }
            openLink(url)
            return true
        }


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
