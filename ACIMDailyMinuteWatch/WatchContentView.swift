import SwiftUI
import SwiftData

struct WatchContentView: View {
    /// ⛔ A `@Query`, not a one-shot read in `.task`. The watch's content
    /// arrives asynchronously — the phone pushes it whenever it likes — and a
    /// view that reads once shows whatever was there when it opened and never
    /// changes. A query redraws when the row lands.
    @Query(sort: \DailyMinute.publishedAt, order: .reverse)
    private var minutes: [DailyMinute]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(sectionTitle)) {
                    if let reading {
                        WatchStoryRow(address: reading.address, text: reading.text)
                    }
                }
            }
            .navigationTitle("ACIM Daily Minute")
        }
    }

    private struct Reading {
        let address: String?
        let text: String
    }

    /// ⛔ **The phone's rule, not a second one.** `Views/Today/TodayView.swift`
    /// decides between the feed and the bundle with exactly these two calls, and
    /// the two surfaces must not disagree about when a cached reading has gone
    /// stale. It also retires a defect of its own: the old code took the newest
    /// row unconditionally, so a week-old minute drew under a heading that said
    /// Today.
    private var isMinuteStale: Bool {
        CorpusFallback.isStale(newest: minutes.first?.publishedAt)
    }

    /// There is no state in which the watch has nothing to say. The bundle is
    /// permanent and answers for every date, so the old "No content yet"
    /// placeholder no longer has a case to cover.
    private var reading: Reading? {
        if !isMinuteStale, let minute = minutes.first {
            // The feed is the authority for today's words; the bundled corpus
            // is what turns the passage's id into its address. That is the
            // same pairing `Views/Today/DailyMinuteCard.swift` makes.
            let segment = CorpusService.shared.segment(id: minute.segmentId)
            return Reading(address: address(of: segment), text: minute.text)
        }
        guard let segment = CorpusFallback.segment(for: Date()) else { return nil }
        return Reading(address: address(of: segment), text: segment.body)
    }

    /// The passage's own address, or the name of the book it came from. ⛔
    /// Nothing is guessed: 118 of the 1,983 segments resolve no citation, and
    /// those show their volume instead — the phone's rule, kept.
    private func address(of segment: CorpusSegment?) -> String? {
        guard let segment else { return nil }
        return segment.citation ?? segment.bookName
    }

    /// The heading tells the truth about what is under it. A bundled reading is
    /// not the publisher's choice for today and must not claim to be.
    private var sectionTitle: String {
        isMinuteStale ? "From the Course" : "Today"
    }
}
