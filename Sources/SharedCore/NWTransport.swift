import Foundation
import Network
import Security

/// Network.framework transport implementing the `Transport` protocol over QUIC with
/// TLS 1.3 (A2 / E1, DG-2). Serves as either listener (agent) or connection (client);
/// messages are framed with `ChannelFraming` over a single ordered stream.
public final class NWTransport: Transport, @unchecked Sendable {
    public var onReceive: ((FramedMessage) -> Void)?
    public var onStateChange: ((TransportState) -> Void)?

    private var listener: NWListener?
    private var connection: NWConnection?
    private var decoder = FrameDecoder()
    private let queue = DispatchQueue(label: "mitm.transport", qos: .userInteractive)

    public init() {}

    /// Starts listening (agent role). `serviceName`, if set, advertises over Bonjour.
    public func listen(port: UInt16, serviceName: String? = nil) throws {
        let listener = try NWListener(using: Self.parameters(),
                                      on: NWEndpoint.Port(rawValue: port) ?? .any)
        if let serviceName {
            listener.service = NWListener.Service(name: serviceName, type: "_mitm._udp")
        }
        listener.newConnectionHandler = { [weak self] connection in self?.adopt(connection) }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.onStateChange?(.failed) }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    /// Connects to a host (client role).
    public func connect(host: String, port: UInt16) {
        let connection = NWConnection(host: NWEndpoint.Host(host),
                                      port: NWEndpoint.Port(rawValue: port) ?? .any,
                                      using: Self.parameters())
        adopt(connection)
    }

    public func send(_ channel: Channel, _ payload: [UInt8]) {
        guard let connection else { return }
        let framed = ChannelFraming.frame(channel, payload)
        connection.send(content: Data(framed), completion: .contentProcessed { _ in })
    }

    public func stop() {
        connection?.cancel(); connection = nil
        listener?.cancel(); listener = nil
    }

    // MARK: - Private

    private func adopt(_ connection: NWConnection) {
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in self?.map(state) }
        receiveLoop(connection)
        connection.start(queue: queue)
    }

    private func map(_ state: NWConnection.State) {
        switch state {
        case .ready:               onStateChange?(.ready)
        case .failed, .waiting:    onStateChange?(.failed)
        case .cancelled:           onStateChange?(.cancelled)
        case .setup, .preparing:   onStateChange?(.setup)
        @unknown default:          break
        }
    }

    private func receiveLoop(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.decoder.push([UInt8](data))
                while let message = self.decoder.next() { self.onReceive?(message) }
            }
            if error != nil { self.onStateChange?(.failed); return }
            if isComplete { self.onStateChange?(.cancelled); return }
            self.receiveLoop(connection)
        }
    }

    private static func parameters() -> NWParameters {
        let quic = NWProtocolQUIC.Options(alpn: ["mitm-v1"])
        let security = quic.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(security, .TLSv13)

        // Pre-shared key so the TLS 1.3 handshake completes without a server certificate
        // (symmetric: both listener and client use the same PSK).
        // TODO: derive this from the ECDH pairing secret instead of a fixed dev key (DG-3).
        let psk = Data("mitm-dev-psk-v1".utf8).withUnsafeBytes { DispatchData(bytes: $0) }
        let pskIdentity = Data("mitm".utf8).withUnsafeBytes { DispatchData(bytes: $0) }
        sec_protocol_options_add_pre_shared_key(security, psk as __DispatchData, pskIdentity as __DispatchData)

        let parameters = NWParameters(quic: quic)
        parameters.allowLocalEndpointReuse = true
        return parameters
    }
}
