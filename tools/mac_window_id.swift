import CoreGraphics
import Foundation

let opts = CGWindowListOption.optionOnScreenOnly.union(.excludeDesktopElements)
guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}
for w in info {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    let layer = w[kCGWindowLayer as String] as? Int ?? -1
    guard layer == 0, owner == "ACIM Daily Minute" else { continue }
    if let num = w[kCGWindowNumber as String] as? Int {
        let bounds = w[kCGWindowBounds as String] as? [String: Any]
        let x = bounds?["X"] as? NSNumber
        let y = bounds?["Y"] as? NSNumber
        let width = bounds?["Width"] as? NSNumber
        let height = bounds?["Height"] as? NSNumber
        if CommandLine.arguments.contains("--bounds") {
            print("\(num) \(x?.intValue ?? 0) \(y?.intValue ?? 0) \(width?.intValue ?? 0) \(height?.intValue ?? 0)")
        } else {
            print(num)
        }
        exit(0)
    }
}
exit(1)
