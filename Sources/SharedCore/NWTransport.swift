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
    public func listen(port: UInt16, serviceName: String? = nil, identity: sec_identity_t? = nil) throws {
        let listener = try NWListener(using: Self.parameters(identity: identity),
                                      on: NWEndpoint.Port(rawValue: port) ?? .any)
        if let serviceName {
            listener.service = NWListener.Service(name: serviceName, type: "_mitm._udp")
        }
        listener.newConnectionHandler = { [weak self] connection in self?.adopt(connection) }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error), .waiting(let error):
                FileHandle.standardError.write(Data("listener \(state): \(error)\n".utf8))
                self?.onStateChange?(.failed)
            default:
                FileHandle.standardError.write(Data("listener: \(state)\n".utf8))
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    /// Connects to a host (client role).
    public func connect(host: String, port: UInt16) {
        connect(to: .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? .any))
    }

    /// Connects to a discovered Bonjour endpoint (no IP typing needed).
    public func connect(to endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: Self.parameters(identity: nil))
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
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .failed, .cancelled:
                if self.connection === connection { self.connection = nil }
            default:
                break
            }
            self.map(state)
        }
        receiveLoop(connection)
        connection.start(queue: queue)
    }

    private func map(_ state: NWConnection.State) {
        switch state {
        case .ready:
            onStateChange?(.ready)
        case .failed(let error), .waiting(let error):
            FileHandle.standardError.write(Data("connection \(state): \(error)\n".utf8))
            onStateChange?(.failed)
        case .cancelled:
            onStateChange?(.cancelled)
        case .setup, .preparing:
            onStateChange?(.setup)
        @unknown default:
            break
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

    private static func parameters(identity: sec_identity_t?) -> NWParameters {
        // A2 QUIC + TLS 1.3 (DG-2). The server (listener) presents a self-signed identity;
        // the client accepts it (real authentication is layered on via ECDH pairing, DG-3).
        let quic = NWProtocolQUIC.Options(alpn: ["mitm-v1"])
        let security = quic.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(security, .TLSv13)

        if let identity {
            sec_protocol_options_set_local_identity(security, identity)   // server role
        } else {
            // client role: accept the dev self-signed certificate
            sec_protocol_options_set_verify_block(security, { _, _, complete in complete(true) },
                                                  DispatchQueue.global())
        }

        let parameters = NWParameters(quic: quic)
        parameters.allowLocalEndpointReuse = true
        return parameters
    }
}
