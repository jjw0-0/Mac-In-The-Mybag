import XCTest
@testable import SharedCore

/// Client session wiring, verified against an in-memory transport.
final class ClientSessionTests: XCTestCase {

    private final class FakeTransport: Transport {
        var onReceive: ((FramedMessage) -> Void)?
        var onStateChange: ((TransportState) -> Void)?
        var sent: [(Channel, [UInt8])] = []
        func send(_ channel: Channel, _ payload: [UInt8]) { sent.append((channel, payload)) }
        func stop() {}
        func inject(_ message: FramedMessage) { onReceive?(message) }
    }

    func testSendStampsMonotonicSequenceOnInputChannel() throws {
        let transport = FakeTransport()
        let session = ClientSession(transport: transport)
        session.send(.mouseButton(.left, .down))
        session.send(.mouseButton(.left, .up))

        XCTAssertEqual(transport.sent.count, 2)
        XCTAssertEqual(transport.sent[0].0, .input)
        let first = try InputCodec.decode(transport.sent[0].1)
        let second = try InputCodec.decode(transport.sent[1].1)
        XCTAssertEqual(first.sequence, 1)
        XCTAssertEqual(second.sequence, 2)
    }

    func testGestureExpandsToMultipleInputs() {
        let transport = FakeTransport()
        let session = ClientSession(transport: transport)
        session.send(gesture: .tap) // down + up
        XCTAssertEqual(transport.sent.count, 2)
        XCTAssertTrue(transport.sent.allSatisfy { $0.0 == .input })
    }

    func testRequestKeyframeSendsControl() throws {
        let transport = FakeTransport()
        let session = ClientSession(transport: transport)
        session.requestKeyframe()
        XCTAssertEqual(transport.sent.count, 1)
        XCTAssertEqual(transport.sent[0].0, .control)
        XCTAssertEqual(try ControlCodec.decode(transport.sent[0].1), .requestKeyframe)
    }

    func testIncomingVideoFrameSurfaces() {
        let transport = FakeTransport()
        let session = ClientSession(transport: transport)
        var received: (VideoFrameHeader, [UInt8])?
        session.onVideoFrame = { received = ($0, $1) }

        let header = VideoFrameHeader(isKeyframe: true, sequence: 1, ptsMicros: 0, width: 1280, height: 800)
        let payload: [UInt8] = [9, 8, 7]
        transport.inject(FramedMessage(channel: .video, payload: header.encoded() + payload))

        XCTAssertEqual(received?.0, header)
        XCTAssertEqual(received?.1, payload)
    }

    func testIncomingControlSurfaces() {
        let transport = FakeTransport()
        let session = ClientSession(transport: transport)
        var control: ControlMessage?
        session.onControl = { control = $0 }
        transport.inject(FramedMessage(channel: .control, payload: ControlCodec.encode(.pong(nonce: 1, sentMicros: 2))))
        XCTAssertEqual(control, .pong(nonce: 1, sentMicros: 2))
    }
}
