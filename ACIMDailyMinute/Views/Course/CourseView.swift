import SwiftUI
import SwiftData

/// The Course tab: four books, then a spine, then a reading.
struct CourseView: View {
    @Binding var path: NavigationPath

    @Environment(\.modelContext) private var modelContext
    @Environment(ConnectivityManager.self) private var connectivity
    @Environment(AudioManager.self) private var audio

    @Query(sort: \DailyLesson.lessonNumber) private var lessons: [DailyLesson]
    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-lesson" },
        sort: \ArchivedReading.lessonNumber
    )
    private var archivedLessons: [ArchivedReading]
    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-minute" },
        sort: \ArchivedReading.dateString
    )
    private var archivedMinutes: [ArchivedReading]
    @Query private var storedMinutes: [DailyMinute]
    @Query private var podcasts: [CachedPodcastEpisode]

    @State private var searchText: String = ""
    @AppStorage(WorkbookCompletion.defaultsKey) private var completedLessonsData: Data = Data()
    @AppStorage(ReadingPositionStore.defaultsKey) private var readingPositionsData: Data = Data()

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if trimmedQuery.isEmpty {
                    contents
                } else {
                    ReadSearchResultsList(query: trimmedQuery)
                }
            }
            .acimInkBackground()
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .courseDestinations(path: $path)
            .readingDestinations(path: $path)
            #if !os(tvOS)
            .searchable(text: $searchText, prompt: "Search the Course")
            .refreshable {
                if connectivity.isConnected {
                    await refresh(force: true)
                }
            }
            .task { await refresh(force: false) }
            #endif
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: audio.hasActiveAudio ? MiniPlayerView.height : 0)
            }
        }
    }

    private var contents: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Course")
                    .font(.acimMasthead)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 8)

                ForEach(Array(CourseShelf.allCases.enumerated()), id: \.element) { index, book in
                    if index > 0 {
                        Color.acimHairline
                            .frame(height: 1)
                    }
                    Button {
                        path.append(book)
                    } label: {
                        CourseBookRow(
                            book: book,
                            count: count(for: book),
                            sub: sub(for: book),
                            progress: progress(for: book),
                            pips: pips(for: book)
                        )
                    }
                    .buttonStyle(.plain)
                }

                fallOpenCard
                    .padding(.top, 22)
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .readableContentWidth()
        }
        .acimInkBackground()
    }

    // MARK: - Book rows

    private func count(for book: CourseShelf) -> String {
        switch book {
        case .minute:
            let n = minuteDates.count
            return n == 1 ? "1 day" : "\(n) days"
        case .lesson:
            let n = WorkbookCompletion.entries.count
            return "\(n) of 365"
        case .text:
            return "31 chapters"
        case .manual:
            return "31 sections"
        }
    }

    private func sub(for book: CourseShelf) -> String {
        _ = readingPositionsData
        switch book {
        case .minute:
            return "One passage a day, drawn from the Text"
        case .lesson:
            if let key = ReadingPositionStore.position(for: .workbook)
                .flatMap({ ReadingKey(rawValue: $0.readingKey) }) {
                return key.displayName()
            }
            if let n = currentWorkbookLesson ?? recordedAnchor().number.nonZero {
                if let title = WorkbookCatalog.title(for: n) {
                    return "Lesson \(n) — \(title)"
                }
                return "Lesson \(n)"
            }
            return "Workbook for Students"
        case .text:
            if let key = ReadingPositionStore.position(for: .text)
                .flatMap({ ReadingKey(rawValue: $0.readingKey) }) {
                return key.displayName()
            }
            return "Not started"
        case .manual:
            if let key = ReadingPositionStore.position(for: .manual)
                .flatMap({ ReadingKey(rawValue: $0.readingKey) }) {
                return key.displayName()
            }
            return "Not started"
        }
    }

    private func progress(for book: CourseShelf) -> Double? {
        _ = completedLessonsData
        switch book {
        case .minute:
            return nil
        case .lesson:
            let n = WorkbookCompletion.entries.count
            return n > 0 ? Double(n) / 365 : nil
        case .text:
            guard let key = ReadingPositionStore.position(for: .text)
                .flatMap({ ReadingKey(rawValue: $0.readingKey) }),
                  case .textSection(let chapter, _) = key, chapter > 0
            else { return nil }
            return Double(chapter) / 31
        case .manual:
            guard let key = ReadingPositionStore.position(for: .manual)
                .flatMap({ ReadingKey(rawValue: $0.readingKey) }),
                  case .manualSection(let n) = key
            else { return nil }
            return n > 0 ? Double(n) / 31 : nil
        }
    }

    private func pips(for book: CourseShelf) -> [CoursePip] {
        switch book {
        case .minute:
            return [
                CoursePip(label: "recorded", present: recordedMinuteCount > 0),
                CoursePip(label: "filmed", present: filmedMinuteCount > 0)
            ]
        case .lesson:
            return [
                CoursePip(label: "audio", present: lessonAudioCount > 0),
                CoursePip(label: "video", present: lessonVideoCount > 0),
                CoursePip(label: "\(WorkbookBodiesCatalog.allIntroductions.count) introductions", present: false)
            ]
        case .text:
            let sections = CorpusService.shared.textChapters.reduce(0) { $0 + $1.sections.count }
            return [
                CoursePip(label: "\(sections) sections", present: false),
                CoursePip(label: "composed", present: true)
            ]
        case .manual:
            return [
                CoursePip(label: "questions", present: !CorpusService.shared.manualSections.isEmpty),
                CoursePip(label: "composed", present: true)
            ]
        }
    }

    private var recordedMinuteCount: Int {
        var dates = Set<String>()
        for minute in storedMinutes where ListenLibrary.showsPlay(audioURL: minute.audioURL ?? "") {
            dates.insert(minute.date)
        }
        for reading in archivedMinutes where ListenLibrary.showsPlay(audioURL: reading.audioURL ?? "") {
            dates.insert(reading.dateString)
        }
        return dates.count
    }

    private var filmedMinuteCount: Int {
        archivedMinutes.filter { !($0.youtubeID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private var lessonAudioCount: Int {
        var numbers = Set<Int>()
        for lesson in lessons where ListenLibrary.showsPlay(audioURL: lesson.audioURL ?? "") {
            numbers.insert(lesson.lessonNumber)
        }
        for reading in archivedLessons where ListenLibrary.showsPlay(audioURL: reading.audioURL ?? "") {
            if let n = reading.lessonNumber { numbers.insert(n) }
        }
        return numbers.count
    }

    private var lessonVideoCount: Int {
        var numbers = Set<Int>()
        for lesson in lessons where !((lesson.youtubeID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            numbers.insert(lesson.lessonNumber)
        }
        for reading in archivedLessons where !((reading.youtubeID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            if let n = reading.lessonNumber { numbers.insert(n) }
        }
        return numbers.count
    }

    // MARK: - Fall open

    private var fallOpenCard: some View {
        Button(action: fallOpen) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Let it fall open")
                        .font(.acimCardTitle)
                        .foregroundStyle(.primary)
                    Text("A published minute, or a passage from the Text.")
                        .font(.acimCardBody)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(Metric.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: Metric.card, style: .continuous)
                    .stroke(Color.acimRule, lineWidth: 1)
            }
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
    }

    private func fallOpen() {
        let opening = FallOpen.opening(
            publishedDates: publishedMinuteDates,
            segmentIDs: textSegmentIDs,
            pickIndex: { Int.random(in: 0..<$0) }
        )
        switch opening {
        case .publishedMinute(let dateString):
            path.append(CourseShelf.minute)
            path.append(MinuteDateRef(dateString: dateString))
        case .bundledSegment(let id):
            path.append(SegmentReadingRef(segmentId: id))
        case nil:
            break
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

    // MARK: - Shared data

    private var minuteDates: Set<String> {
        var dates = Set(archivedMinutes.map(\.dateString).filter { !$0.isEmpty })
        for minute in storedMinutes where !minute.date.isEmpty {
            dates.insert(minute.date)
        }
        return dates
    }

    private var currentWorkbookLesson: Int? {
        #if os(tvOS)
        nil
        #else
        PracticeReminderService.currentLesson()
        #endif
    }

    private func recordedAnchor() -> (number: Int, date: Date?) {
        let anchor = LessonSchedule.anchor(
            from: lessons.map { ($0.lessonNumber, $0.publishedAt) }
                + archivedLessons.map { ($0.lessonNumber ?? 0, $0.timestamp) }
        )
        return (anchor?.number ?? 0, anchor?.date)
    }

    @MainActor
    private func refresh(force: Bool) async {
        let service = DataService(modelContainer: modelContext.container)
        do {
            async let minuteDTO = service.fetchDailyMinute(force: force)
            async let lessonDTO = service.fetchDailyLesson(force: force)
            let (m, l) = try await (minuteDTO, lessonDTO)
            if let m { try DataService.persistMinute(m, in: modelContext) }
            if let l { try DataService.persistLesson(l, in: modelContext) }
        } catch {}
        let podcastService = PodcastService()
        do {
            async let minutes = podcastService.fetchMinuteEpisodes(force: force)
            async let lessonEpisodes = podcastService.fetchLessonEpisodes(force: force)
            let (m, l) = try await (minutes, lessonEpisodes)
            try PodcastService.persist(m, channel: "minute", in: modelContext)
            try PodcastService.persist(l, channel: "lesson", in: modelContext)
        } catch {}
    }
}

private extension Int {
    var nonZero: Int? { self > 0 ? self : nil }
}

/// One book's spine. Course contents pushes this; the iPad/Mac split
/// shows it as the detail root.
struct CourseSpineView: View {
    let book: CourseShelf
    @Binding var path: NavigationPath

    var body: some View {
        switch book {
        case .minute:
            CourseMinuteSpine(path: $path)
        case .lesson:
            CourseWorkbookSpine(path: $path)
        case .text:
            CourseTextSpine()
        case .manual:
            CourseManualSpine()
        }
    }
}

extension View {
    /// Book, lesson, minute, Text, Manual, and segment destinations for a
    /// Course stack. `readingDestinations` is separate and still required.
    func courseDestinations(path: Binding<NavigationPath>) -> some View {
        modifier(CourseDestinationsModifier(path: path))
    }
}

private struct CourseDestinationsModifier: ViewModifier {
    @Binding var path: NavigationPath

    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-minute" },
        sort: \ArchivedReading.dateString
    )
    private var archivedMinutes: [ArchivedReading]
    @Query private var storedMinutes: [DailyMinute]

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: CourseShelf.self) { book in
                CourseSpineView(book: book, path: $path)
            }
            .navigationDestination(for: Int.self) { lessonNumber in
                LessonDetailView(lessonNumber: lessonNumber, presentsVideo: false)
            }
            .navigationDestination(for: MinuteDateRef.self) { ref in
                MinuteReadingView(
                    dateString: ref.dateString,
                    availability: minuteAvailability(of: ref.dateString),
                    archived: minuteDates
                )
            }
            .navigationDestination(for: TextChapterRef.self) { ref in
                TextChapterView(chapter: ref.chapter)
            }
            .navigationDestination(for: IntroductionRef.self) { ref in
                WorkbookIntroductionView(lessonNumber: ref.lessonNumber, spotlight: ref.spotlight)
            }
            .navigationDestination(for: LessonRef.self) { ref in
                LessonDetailView(
                    lessonNumber: ref.lessonNumber,
                    spotlight: ref.spotlight,
                    presentsVideo: ref.presentsVideo
                )
            }
            .navigationDestination(for: ManualSegmentRef.self) { ref in
                ManualSegmentView(segmentId: ref.segmentId, spotlight: ref.spotlight)
            }
            .navigationDestination(for: ManualSectionRef.self) { ref in
                ManualSectionView(number: ref.number, spotlight: ref.spotlight)
            }
            .navigationDestination(for: SegmentReadingRef.self) { ref in
                SegmentReadingView(segmentId: ref.segmentId, spotlight: ref.spotlight)
            }
    }

    private var minuteDates: Set<String> {
        var dates = Set(archivedMinutes.map(\.dateString).filter { !$0.isEmpty })
        for minute in storedMinutes where !minute.date.isEmpty {
            dates.insert(minute.date)
        }
        return dates
    }

    private func minuteAvailability(of dateString: String) -> MinuteSchedule.Availability {
        guard let day = LessonSchedule.day(from: dateString) else { return .unknown }
        return MinuteSchedule.availability(
            of: day,
            archived: minuteDates,
            today: MinuteSchedule.utcToday(now: Date())
        )
    }
}

struct CoursePip: Identifiable {
    let label: String
    let present: Bool
    var id: String { label }
}

struct CourseBookRow: View {
    let book: CourseShelf
    let count: String
    let sub: String
    let progress: Double?
    let pips: [CoursePip]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(book.bookName)
                    .font(.acimSubject)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(count)
                    .font(.acimMastheadSub)
                    .foregroundStyle(.secondary)
            }
            Text(sub)
                .font(.acimSubjectSub)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            if let progress {
                CourseProgressHairline(fraction: progress)
                    .padding(.top, 11)
            }
            HStack(spacing: 7) {
                ForEach(pips) { pip in
                    Text(pip.label)
                        .font(.acimChipText)
                        .foregroundStyle(pip.present ? Color.acimGold : Color.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .overlay {
                            Capsule()
                                .stroke(pip.present ? Color.acimRule : Color.acimHairline, lineWidth: 1)
                        }
                }
            }
            .padding(.top, 11)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct CourseProgressHairline: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.acimRaised)
                Rectangle()
                    .fill(Color.acimGold)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: Metric.progressHairline)
    }
}

struct CourseSpineGlyphs: View {
    let hasAudio: Bool
    let hasVideo: Bool

    var body: some View {
        HStack(spacing: 6) {
            if hasAudio {
                Image(systemName: "waveform")
            }
            if hasVideo {
                Image(systemName: "play.rectangle")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.acimGold.opacity(0.85))
        .accessibilityHidden(true)
    }
}

struct CourseSearchField: View {
    @Binding var text: String
    var prompt: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
        }
        .font(.acimChrome)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.acimRaised, in: RoundedRectangle(cornerRadius: Metric.field, style: .continuous))
    }
}

struct CourseSpineMasthead: View {
    let title: String
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.acimMasthead)
                .foregroundStyle(.primary)
            Text(sub)
                .font(.acimMastheadSub)
                .foregroundStyle(.secondary)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
