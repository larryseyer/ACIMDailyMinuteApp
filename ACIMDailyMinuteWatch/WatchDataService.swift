import Foundation
import SwiftData
import WatchConnectivity
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The watch's one moving part: it opens the cache store and receives what the
/// phone pushes. It fetches nothing of its own.
///
/// ⛔ **The watch has no network layer, and that is deliberate rather than
/// missing.** What it can show without a phone comes from the bundled corpus
/// (`CorpusFallback`), which is permanent; what it shows about *today* comes
/// from the phone over `WCSession`, which is the only party that knows the
/// publisher's choice. A third path — the watch fetching the feed itself —
/// would be a second implementation of `DataService`'s persist rules, and two
/// implementations of an identity rule that must agree is how duplicate rows
/// are born.
final class WatchDataService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchDataService()

    let container: ModelContainer

    private override init() {
        // ⛔ Cache only. The watch draws today's minute and touches no reader
        // model anywhere in its own sources, so it has no reason to open
        // `reader.store` and one good reason not to: were that store ever
        // mirrored here, the watch would pull down every highlight and note the
        // reader has ever written onto a device with no screen to show them. It
        // also keeps iCloud off this target's entitlements entirely.
        //
        // Still one declaration, not two — the difference is a parameter.
        do {
            container = try SharedModelContainer.makeContainer(
                allowsSave: true,
                includeReader: false
            )
        } catch {
            fatalError("Could not create Watch ModelContainer: \(error)")
        }
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingPayload(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncomingPayload(applicationContext)
    }

    /// ⛔ `segmentHash` is the row's identity and `segmentId` is the passage's
    /// address; they are not interchangeable. The hash decides whether this is a
    /// reading the watch already holds. The id is what lets the watch name where
    /// the passage sits in the book, through the same bundled corpus lookup the
    /// phone's card uses — so the two surfaces cannot disagree about an address.
    ///
    /// The lesson keys are independent. A payload may carry the minute, the
    /// lesson, or both; missing keys skip that half rather than dropping the
    /// other.
    private func handleIncomingPayload(_ payload: [String: Any]) {
        // Values are lifted off the session thread first: `[String: Any]` is
        // not Sendable, and hopping with the dictionary itself is a data race.
        let minute = IncomingMinute(payload)
        let lesson = IncomingLesson(payload)
        Task { @MainActor in
            var changed = false
            if let minute, persist(minute) { changed = true }
            if let lesson, persist(lesson) { changed = true }
            guard changed else { return }
            try? container.mainContext.save()
            // ⛔ The complication does NOT observe the store. Its provider is
            // asked once and then not again until the timeline's own hour is
            // up, so without this the face keeps yesterday's passage for up to
            // an hour after the phone has pushed today's — and the app beside
            // it, which does watch the store through `@Query`, disagrees with
            // it on the same wrist. `DataService` owes the same line on iOS
            // for the same reason.
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    private struct IncomingMinute: Sendable {
        let text: String
        let publishedAt: Date
        let date: String
        let segmentHash: String
        let segmentId: Int

        init?(_ payload: [String: Any]) {
            guard let text = payload["text"] as? String,
                  let publishedInterval = payload["publishedAt"] as? TimeInterval,
                  let date = payload["date"] as? String,
                  let segmentHash = payload["segmentHash"] as? String else { return nil }
            self.text = text
            self.publishedAt = Date(timeIntervalSince1970: publishedInterval)
            self.date = date
            self.segmentHash = segmentHash
            self.segmentId = payload["segmentId"] as? Int ?? 0
        }
    }

    private struct IncomingLesson: Sendable {
        let text: String
        let number: Int
        let title: String
        let date: String
        let publishedAt: Date
        let hash: String

        init?(_ payload: [String: Any]) {
            guard let text = payload["lessonText"] as? String,
                  let number = payload["lessonNumber"] as? Int,
                  let publishedInterval = payload["lessonPublishedAt"] as? TimeInterval,
                  let date = payload["lessonDate"] as? String else { return nil }
            self.text = text
            self.number = number
            self.title = payload["lessonTitle"] as? String ?? ""
            self.date = date
            self.publishedAt = Date(timeIntervalSince1970: publishedInterval)
            self.hash = payload["lessonHash"] as? String ?? ""
        }
    }

    @MainActor
    private func persist(_ incoming: IncomingMinute) -> Bool {
        let segmentHash = incoming.segmentHash
        let descriptor = FetchDescriptor<DailyMinute>(
            predicate: #Predicate { $0.segmentHash == segmentHash }
        )
        let existing = try? container.mainContext.fetch(descriptor)
        let minute = existing?.first ?? DailyMinute()
        let isNew = minute.segmentHash.isEmpty
        minute.segmentId = incoming.segmentId
        minute.segmentHash = incoming.segmentHash
        minute.date = incoming.date
        minute.publishedAt = incoming.publishedAt
        minute.text = incoming.text
        if isNew { container.mainContext.insert(minute) }
        return true
    }

    @MainActor
    private func persist(_ incoming: IncomingLesson) -> Bool {
        let number = incoming.number
        let descriptor = FetchDescriptor<DailyLesson>(
            predicate: #Predicate { $0.lessonNumber == number }
        )
        let existing = try? container.mainContext.fetch(descriptor)
        let lesson = existing?.first ?? DailyLesson()
        let isNew = existing?.first == nil
        lesson.lessonNumber = incoming.number
        lesson.lessonTitle = incoming.title
        lesson.segmentHash = incoming.hash
        lesson.date = incoming.date
        lesson.publishedAt = incoming.publishedAt
        lesson.text = incoming.text
        if isNew { container.mainContext.insert(lesson) }
        return true
    }
}
