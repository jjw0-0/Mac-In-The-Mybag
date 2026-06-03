import XCTest
@testable import SharedCore

/// 연결 상태 머신 — UT-S1(합법 전이) / UT-S2(불법 전이 거부).
final class ConnectionStateTests: XCTestCase {

    func testHappyPath() {
        var m = ConnectionStateMachine()
        XCTAssertTrue(m.apply(.startDiscovery)); XCTAssertEqual(m.state, .discovering)
        XCTAssertTrue(m.apply(.peerFound));      XCTAssertEqual(m.state, .handshaking)
        XCTAssertTrue(m.apply(.handshakeOK));    XCTAssertEqual(m.state, .connected)
    }

    func testReconnectCycle() {
        var m = ConnectionStateMachine(state: .connected)
        XCTAssertTrue(m.apply(.linkLost));    XCTAssertEqual(m.state, .reconnecting)
        XCTAssertTrue(m.apply(.reconnected)); XCTAssertEqual(m.state, .connected)
    }

    func testIllegalTransitionRejected() {
        var m = ConnectionStateMachine()        // idle
        XCTAssertFalse(m.apply(.handshakeOK))   // idle에서 불법
        XCTAssertEqual(m.state, .idle)          // 상태 불변
    }

    func testStopFromAnyState() {
        var m = ConnectionStateMachine(state: .connected)
        XCTAssertTrue(m.apply(.stop))
        XCTAssertEqual(m.state, .disconnected)
    }
}
