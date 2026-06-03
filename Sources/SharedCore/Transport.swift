import Foundation

/// Lifecycle state of a transport connection.
public enum TransportState: Equatable, Sendable {
    case setup
    case ready
    case failed
    case cancelled
}

public enum TransportError: Error, Equatable {
    case notReady
    case listenFailed
    case connectFailed
}

/// Abstraction over the secure transport (the production form is A2 QUIC + TLS 1.3,
/// per DG-2). Concrete implementations live in the platform targets; the channel framing
/// (`ChannelFraming`) keeps the byte stream self-describing regardless of the backend.
public protocol Transport: AnyObject {
    var onReceive: ((FramedMessage) -> Void)? { get set }
    var onStateChange: ((TransportState) -> Void)? { get set }

    func send(_ channel: Channel, _ payload: [UInt8])
    func stop()
}
