#if os(iOS) || os(macOS)
import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

/// Sidebar destinations for iPad and Mac. iPhone keeps the three tabs.
enum SplitItem: Hashable {
    case today
    case book(CourseShelf)
    case saved
}

/// iPad and Mac chrome. Sidebar holds Today, the four books, and Saved;
/// the detail column is the selected surface. No tab bar.
struct ACIMSplitView: View {
    @Binding var selection: SplitItem
    @Binding var path: NavigationPath
    @Binding var preservePath: Bool

    @Environment(AudioManager.self) private var audio
    #if os(macOS)
    /// Start collapsed so a restored 500pt window cannot clip the books
    /// on first paint. Expands to both columns once the window is wide.
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    #endif
    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-minute" },
        sort: \ArchivedReading.dateString
    )
    private var archivedMinutes: [ArchivedReading]
    @Query private var storedMinutes: [DailyMinute]

    #if os(macOS)
    /// Sidebar 240 plus a reading column that is not the 420pt window
    /// minimum. Below this, both columns fight and labels clip.
    private static let macSplitFits: CGFloat = 720
    #endif

    var body: some View {
        splitView
            .navigationSplitViewStyle(.balanced)
            .environment(\.clampsReadableColumn, true)
            .onChange(of: selection) { _, _ in
                if preservePath {
                    preservePath = false
                    return
                }
                path = NavigationPath()
            }
    }

    /// iPad keeps both columns so the 672pt clamp never sees a full-window
    /// parent. Mac shows both when the window is at least `macSplitFits`,
    /// and collapses to the reading at the 420pt minimum.
    private var splitView: some View {
        #if os(iOS)
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } detail: {
            detail
        }
        #else
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } detail: {
            detail
        }
        .background {
            MacWindowWidthReader(onChange: applyMacVisibility)
        }
        #endif
    }

    #if os(macOS)
    private func applyMacVisibility(_ width: CGFloat) {
        let next: NavigationSplitViewVisibility = width < Self.macSplitFits ? .detailOnly : .all
        if columnVisibility != next {
            columnVisibility = next
        }
    }
    #endif

    private var sidebar: some View {
        List(selection: optionalSelection) {
            NavigationLink(value: SplitItem.today) {
                Label("Today", systemImage: "sun.max.fill")
            }
            Section {
                ForEach(CourseShelf.allCases) { book in
                    NavigationLink(value: SplitItem.book(book)) {
                        Text(book.bookName)
                    }
                }
                Button(action: fallOpen) {
                    Text("Let it fall open")
                }
                .buttonStyle(.plain)
            }
            NavigationLink(value: SplitItem.saved) {
                Label("Saved", systemImage: "bookmark.fill")
            }
        }
        .listStyle(.sidebar)
        .acimInkListBackground()
    }

    /// iOS `List(selection:)` takes an optional; Mac's non-optional
    /// initializer is marked unavailable on iOS.
    private var optionalSelection: Binding<SplitItem?> {
        Binding(
            get: { selection },
            set: { if let value = $0 { selection = value } }
        )
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .today:
            TodayView()
        case .saved:
            SavedView()
        case .book(let book):
            NavigationStack(path: $path) {
                CourseSpineView(book: book, path: $path)
                    .courseDestinations(path: $path)
                    .readingDestinations(path: $path)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
                    }
            }
        }
    }

    private func fallOpen() {
        let opening = FallOpen.opening(
            publishedDates: publishedMinuteDates,
            segmentIDs: textSegmentIDs,
            pickIndex: { Int.random(in: 0..<$0) }
        )
        switch opening {
        case .publishedMinute(let dateString):
            open(.book(.minute), pushing: MinuteDateRef(dateString: dateString))
        case .bundledSegment(let id):
            open(.book(.text), pushing: SegmentReadingRef(segmentId: id))
        case nil:
            break
        }
    }

    private func open<Value: Hashable>(_ item: SplitItem, pushing value: Value) {
        var next = NavigationPath()
        next.append(value)
        if selection == item {
            path = next
        } else {
            preservePath = true
            selection = item
            path = next
        }
    }

    private var publishedMinuteDates: [String] {
        var seen = Set<String>()
        var dates: [String] = []
        for reading in archivedMinutes {
            let key = reading.dateString
            if !key.isEmpty, seen.insert(key).inserted {
                dates.append(key)
            }
        }
        for minute in storedMinutes where !minute.date.isEmpty {
            if seen.insert(minute.date).inserted {
                dates.append(minute.date)
            }
        }
        return dates
    }

    private var textSegmentIDs: [Int] {
        CorpusService.shared.allSegmentIDs.filter {
            CorpusService.shared.segment(id: $0)?.bookName == "Text"
        }
    }
}

#if os(macOS)
/// Reports the real NSWindow width. GeometryReader on a split view is
/// the column, not the window, so it cannot decide when to collapse.
private struct MacWindowWidthReader: NSViewRepresentable {
    var onChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? TrackingView)?.onChange = onChange
    }

    private final class TrackingView: NSView {
        var onChange: ((CGFloat) -> Void)?
        private var observer: NSObjectProtocol?

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
            super.viewWillMove(toWindow: newWindow)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            report(window.frame.width)
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] note in
                guard let window = note.object as? NSWindow else { return }
                self?.report(window.frame.width)
            }
        }

        private func report(_ width: CGFloat) {
            onChange?(width)
        }
    }
}
#endif
#endif
