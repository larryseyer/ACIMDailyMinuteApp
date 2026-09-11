// ⛔ WatchConnectivity does not exist on tvOS — there is no wrist to reach
// from a television — so the whole file is fenced on the framework. One fence,
// not the three this file used to carry: `canImport` states the real dependency
// and `os(iOS)` narrows it to the platform that actually pairs with a watch.
#if os(iOS) && canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

final class PhoneWatchSyncService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneWatchSyncService()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// One payload. `WCSession.updateApplicationContext` keeps a single
    /// dictionary: a second send would replace the first, so the minute and
    /// the lesson travel together or the watch would only ever hold one.
    func sendLatest(minute: DailyMinute?, lesson: DailyLesson?) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var payload: [String: Any] = [:]
        if let minute {
            // ⛔ `segmentId` is the passage's ADDRESS and `segmentHash` is the
            // row's IDENTITY. The watch needs both and they do different jobs:
            // the hash says whether this is a reading it already holds, the id
            // is what lets it name where the passage sits in the book through
            // the same bundled corpus lookup `DailyMinuteCard` uses.
            payload["text"] = minute.text
            payload["publishedAt"] = minute.publishedAt.timeIntervalSince1970
            payload["date"] = minute.date
            payload["segmentHash"] = minute.segmentHash
            payload["segmentId"] = minute.segmentId
        }
        if let lesson {
            payload["lessonText"] = lesson.text
            payload["lessonTitle"] = lesson.lessonTitle
            payload["lessonNumber"] = lesson.lessonNumber
            payload["lessonDate"] = lesson.date
            payload["lessonPublishedAt"] = lesson.publishedAt.timeIntervalSince1970
            payload["lessonHash"] = lesson.segmentHash
        }
        guard !payload.isEmpty else { return }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            try? session.updateApplicationContext(payload)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
