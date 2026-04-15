import Foundation

enum DeepLinkRoute {
    case today
    case lesson(Int)
    case archive(Date)
    case saved

    static func parse(_ url: URL) -> DeepLinkRoute? {
        guard url.scheme == "acimdailyminute" else { return nil }
        let host = url.host ?? url.pathComponents.first(where: { $0 != "/" }) ?? ""
        let segments = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "today": return .today
        case "saved": return .saved
        case "lesson":
            guard let n = segments.first.flatMap(Int.init), (1...365).contains(n) else { return nil }
            return .lesson(n)
        case "archive":
            guard let raw = segments.first else { return nil }
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyy-MM-dd"
            guard let d = f.date(from: raw) else { return nil }
            return .archive(d)
        default: return nil
        }
    }
}

extension Notification.Name {
    static let deepLinkLesson = Notification.Name("acim.deepLink.lesson")
    static let deepLinkArchive = Notification.Name("acim.deepLink.archive")
}
