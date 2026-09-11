import SwiftUI
import SwiftData

/// Workbook spine: 1...365, introductions riding alongside, jump-to-N.
struct CourseWorkbookSpine: View {
    @Binding var path: NavigationPath

    @Query(sort: \DailyLesson.lessonNumber) private var lessons: [DailyLesson]
    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-lesson" },
        sort: \ArchivedReading.lessonNumber
    )
    private var archivedLessons: [ArchivedReading]
    @Query private var bookmarks: [Bookmark]

    @State private var searchText: String = ""
    @State private var isJumpSheetPresented = false
    #if os(tvOS)
    @State private var pendingJump: Int?
    #endif
    @AppStorage(WorkbookCompletion.defaultsKey) private var completedLessonsData: Data = Data()

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let meta = buildMetaIndex()
        let anchor = recordedAnchor()
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                CourseSpineMasthead(
                    title: CourseShelf.lesson.bookName,
                    sub: subLine(anchor: anchor.number)
                )
                #if !os(tvOS)
                CourseSearchField(text: $searchText, prompt: "Search the Workbook")
                    .padding(.top, 14)
                #endif
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if trimmedQuery.isEmpty {
                FilteredLessonsList(
                    meta: meta,
                    bookmarkedNumbers: bookmarkedLessonNumbers(),
                    completedNumbers: Set(WorkbookCompletion.entries.keys),
                    latestLessonNumber: anchor.number,
                    latestPublishedAt: anchor.date,
                    practiceLine: practiceLine(for: anchor.number),
                    onOpenText: { path.append(CourseShelf.text) }
                )
            } else {
                ReadSearchResultsList(query: trimmedQuery)
            }
        }
        .acimInkBackground()
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: jumpPlacement) {
                Button {
                    isJumpSheetPresented = true
                } label: {
                    #if os(tvOS)
                    Text("Jump to Lesson")
                        .fixedSize(horizontal: true, vertical: false)
                    #else
                    Label("Jump", systemImage: "arrow.right.to.line")
                    #endif
                }
                #if os(tvOS)
                .buttonStyle(.bordered)
                #endif
                .accessibilityLabel("Jump to lesson number")
            }
        }
        .sheet(isPresented: $isJumpSheetPresented, onDismiss: openPendingJump) {
            JumpToLessonSheet { n in
                #if os(tvOS)
                pendingJump = n
                #else
                path.append(n)
                #endif
            }
        }
    }

    private func openPendingJump() {
        #if os(tvOS)
        guard let n = pendingJump else { return }
        pendingJump = nil
        path.append(n)
        #endif
    }

    private var jumpPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #elseif os(tvOS)
        .automatic
        #else
        .primaryAction
        #endif
    }

    private var currentWorkbookLesson: Int? {
        #if os(tvOS)
        nil
        #else
        PracticeReminderService.currentLesson()
        #endif
    }

    private func subLine(anchor: Int) -> String {
        if let n = currentWorkbookLesson ?? (anchor > 0 ? anchor : nil) {
            if let title = WorkbookCatalog.title(for: n) {
                return "Lesson \(n) — \(title)"
            }
            return "Lesson \(n)"
        }
        return "Workbook for Students"
    }

    private func practiceLine(for lesson: Int) -> String? {
        guard lesson > 0, let record = WorkbookPracticeCatalog.record(for: lesson) else { return nil }
        return PracticePlanner.cadenceSummary(record)
    }

    private func buildMetaIndex() -> [Int: LessonMeta] {
        var index: [Int: LessonMeta] = [:]

        for archive in archivedLessons {
            guard let n = archive.lessonNumber else { continue }
            index[n] = LessonMeta(
                lessonNumber: n,
                title: archive.text.isEmpty ? nil : archive.text,
                hasFullText: false,
                hasAudio: ListenLibrary.showsPlay(audioURL: archive.audioURL ?? ""),
                hasVideo: !((archive.youtubeID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
        }

        for lesson in lessons {
            let previous = index[lesson.lessonNumber]
            index[lesson.lessonNumber] = LessonMeta(
                lessonNumber: lesson.lessonNumber,
                title: lesson.lessonTitle.isEmpty ? nil : lesson.lessonTitle,
                hasFullText: !lesson.text.isEmpty,
                hasAudio: ListenLibrary.showsPlay(audioURL: lesson.audioURL ?? "")
                    || (previous?.hasAudio == true),
                hasVideo: !((lesson.youtubeID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    || (previous?.hasVideo == true)
            )
        }

        return index
    }

    private func recordedAnchor() -> (number: Int, date: Date?) {
        _ = completedLessonsData
        let anchor = LessonSchedule.anchor(
            from: lessons.map { ($0.lessonNumber, $0.publishedAt) }
                + archivedLessons.map { ($0.lessonNumber ?? 0, $0.timestamp) }
        )
        return (anchor?.number ?? 0, anchor?.date)
    }

    private func bookmarkedLessonNumbers() -> Set<Int> {
        var result: Set<Int> = []
        for bookmark in bookmarks where bookmark.itemKey.hasPrefix("lesson:") {
            let suffix = bookmark.itemKey.dropFirst("lesson:".count)
            if let n = Int(suffix) { result.insert(n) }
        }
        return result
    }
}

/// Owns the `ForEach(1...365)` so `@Query` re-evaluation stays off the rows.
struct FilteredLessonsList: View {
    let meta: [Int: LessonMeta]
    let bookmarkedNumbers: Set<Int>
    let completedNumbers: Set<Int>
    let latestLessonNumber: Int
    let latestPublishedAt: Date?
    let practiceLine: String?
    let onOpenText: () -> Void

    @State private var hasScrolledToCurrent = false

    var body: some View {
        let visible = Array(1...365)
        ScrollViewReader { proxy in
            List {
                if latestLessonNumber > 0 {
                    cadenceHeader
                        #if !os(tvOS)
                        .listRowSeparator(.hidden)
                        #endif
                        .listRowBackground(Color.clear)
                }
                ForEach(visible, id: \.self) { n in
                    ForEach(Self.introductions(before: n), id: \.lessonNumber) { intro in
                        introductionRow(intro.lessonNumber)
                    }
                    LessonRow(
                        lessonNumber: n,
                        meta: meta[n],
                        isBookmarked: bookmarkedNumbers.contains(n),
                        isCompleted: completedNumbers.contains(n),
                        availableOn: latestPublishedAt.flatMap {
                            LessonSchedule.availabilityDate(
                                for: n,
                                latestRecorded: latestLessonNumber,
                                latestDate: $0
                            )
                        },
                        isCurrent: n == latestLessonNumber,
                        practiceLine: n == latestLessonNumber ? practiceLine : nil
                    )
                    .id(n)
                }
            }
            .listStyle(.plain)
            .readableContentWidth()
            .onAppear { scrollToCurrentLesson(proxy: proxy, visible: visible) }
            .onChange(of: latestLessonNumber) { _, _ in
                scrollToCurrentLesson(proxy: proxy, visible: visible)
            }
            .acimInkListBackground()
        }
    }

    private static func introductions(before lessonNumber: Int) -> [WorkbookIntroduction] {
        WorkbookBodiesCatalog.allIntroductions.filter { $0.insertBefore == lessonNumber }
    }

    @ViewBuilder
    private func introductionRow(_ lessonNumber: Int) -> some View {
        if let intro = WorkbookBodiesCatalog.introduction(for: lessonNumber) {
            NavigationLink(value: IntroductionRef(lessonNumber: lessonNumber)) {
                HStack(alignment: .firstTextBaseline, spacing: 13) {
                    Text("")
                        .font(.acimRowNumber)
                        .frame(width: 34, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(intro.title)
                            .font(.acimRowTitle)
                            .foregroundStyle(.primary)
                        Text("Workbook for Students")
                            .font(.acimRowSub)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.vertical, Metric.row)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 13))
            .listRowBackground(Color.clear)
            #if !os(tvOS)
            .listRowSeparator(.hidden)
            #endif
        }
    }

    private func scrollToCurrentLesson(proxy: ScrollViewProxy, visible: [Int]) {
        guard !hasScrolledToCurrent,
              latestLessonNumber > 0,
              visible.contains(latestLessonNumber)
        else { return }

        hasScrolledToCurrent = true
        DispatchQueue.main.async {
            proxy.scrollTo(latestLessonNumber, anchor: .top)
        }
    }

    private var cadenceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lesson \(latestLessonNumber) of 365")
            Button(action: onOpenText) {
                HStack(spacing: 4) {
                    Text("After Lesson 365, the Text begins.")
                    Image(systemName: "chevron.right")
                        .font(.acimCaption2)
                }
            }
            .buttonStyle(.plain)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .listRowInsets(EdgeInsets(top: 8, leading: Metric.gutter, bottom: 8, trailing: Metric.gutter))
    }
}
