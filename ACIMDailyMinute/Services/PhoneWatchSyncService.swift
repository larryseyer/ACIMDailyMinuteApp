import Foundation
#if os(iOS)
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

        let payload: [String: Any] = [
            "text": minute.text,
            "publishedAt": minute.publishedAt.timeIntervalSince1970,
            "date": minute.date,
            "segmentHash": minute.segmentHash
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
