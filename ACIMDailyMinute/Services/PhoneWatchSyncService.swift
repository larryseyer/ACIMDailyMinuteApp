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

    func sendLatestMinute(_ minute: DailyMinute) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        // ⛔ `segmentId` is the passage's ADDRESS and `segmentHash` is the row's
        // IDENTITY. The watch needs both and they do different jobs: the hash
        // says whether this is a reading it already holds, the id is what lets
        // it name where the passage sits in the book through the same bundled
        // corpus lookup `DailyMinuteCard` uses. Without the id the watch can
        // draw the words and say nothing true about them.
        let payload: [String: Any] = [
            "text": minute.text,
            "publishedAt": minute.publishedAt.timeIntervalSince1970,
            "date": minute.date,
            "segmentHash": minute.segmentHash,
            "segmentId": minute.segmentId
        ]

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
