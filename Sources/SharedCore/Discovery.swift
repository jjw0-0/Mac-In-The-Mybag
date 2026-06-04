import Foundation
import Network

/// Browses for agents advertising the `_mitm._udp` Bonjour service (F8 discovery).
///
/// Starting the browser is also what reliably triggers the iOS Local Network permission
/// prompt — a raw-IP `NWConnection` alone often does not.
public final class Discovery {
    public struct Device: Identifiable, Equatable {
        public let name: String
        public let endpoint: NWEndpoint
        public var id: String { name }
    }

    private var browser: NWBrowser?

    /// Called on the main queue whenever the set of discovered devices changes.
    public var onDevices: (([Device]) -> Void)?

    public init() {}

    public func start() {
        guard browser == nil else { return }
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: "_mitm._udp", domain: nil), using: parameters)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let devices = results.compactMap { result -> Device? in
                if case let .service(name, _, _, _) = result.endpoint {
                    return Device(name: name, endpoint: result.endpoint)
                }
                return nil
            }
            self?.onDevices?(devices)
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    public func stop() {
        browser?.cancel()
        browser = nil
    }
}
