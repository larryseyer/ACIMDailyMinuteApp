import Foundation
import Network

@Observable
@MainActor
final class ConnectivityManager {
    var isConnected = true
    var isWiFi = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "connectivity-monitor")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isWiFi = path.usesInterfaceType(.wifi)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
