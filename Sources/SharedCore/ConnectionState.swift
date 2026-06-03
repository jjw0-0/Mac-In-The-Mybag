import Foundation

/// 연결 상태 — UT-S1 전이 매트릭스, AC8 재연결.
public enum ConnectionState: Equatable, Sendable {
    case idle
    case discovering
    case handshaking
    case connected
    case reconnecting
    case disconnected
}

/// 상태 전이 이벤트.
public enum ConnectionEvent: Equatable, Sendable {
    case startDiscovery
    case peerFound
    case handshakeOK
    case linkLost
    case reconnected
    case stop
}

/// 합법 전이만 허용하는 결정적 상태 머신.
/// 불법 전이는 거부하고 상태를 유지한다(UT-S2).
public struct ConnectionStateMachine {
    public private(set) var state: ConnectionState

    public init(state: ConnectionState = .idle) {
        self.state = state
    }

    /// 이벤트를 적용한다. 합법 전이면 상태를 갱신하고 `true`, 불법이면 상태를 유지하고 `false`.
    @discardableResult
    public mutating func apply(_ event: ConnectionEvent) -> Bool {
        switch (state, event) {
        case (.idle, .startDiscovery):       state = .discovering
        case (.discovering, .peerFound):     state = .handshaking
        case (.handshaking, .handshakeOK):   state = .connected
        case (.connected, .linkLost):        state = .reconnecting
        case (.reconnecting, .reconnected):  state = .connected
        case (.reconnecting, .linkLost):     state = .reconnecting   // 재시도 중 추가 손실 흡수
        case (_, .stop):                     state = .disconnected
        default:                             return false
        }
        return true
    }
}
