import XCTest
@testable import SharedCore

/// Control-message codec and video framing round-trips.
final class WireProtocolTests: XCTestCase {

    private func roundtrip(_ message: ControlMessage,
                           file: StaticString = #filePath, line: UInt = #line) throws {
        let decoded = try ControlCodec.decode(ControlCodec.encode(message))
        XCTAssertEqual(decoded, message, file: file, line: line)
    }

    func testControlMessageRoundtrips() throws {
        try roundtrip(.hello(deviceID: UUID()))
        try roundtrip(.helloAck(sessionToken: 0xDEADBEEFCAFE))
        try roundtrip(.ping(nonce: 42, sentMicros: 1_700_000_000_000_000))
        try roundtrip(.pong(nonce: 42, sentMicros: 1_700_000_000_000_001))
        try roundtrip(.requestKeyframe)
        try roundtrip(.setQuality(StreamQuality(fps: 30, resolutionScale: 0.75, codec: .h264, prioritizeInput: false)))
        try roundtrip(.resume(sessionToken: 7, lastInputSequence: 123))
        try roundtrip(.videoFormat(sps: [0x67, 0x42, 0x00], pps: [0x68, 0xCE]))
        try roundtrip(.bye)
    }

    func testUnknownControlTagThrows() {
        XCTAssertThrowsError(try ControlCodec.decode([0xEE])) { error in
            XCTAssertEqual(error as? InputCodecError, .unknownEventType(0xEE))
        }
    }

    func testTrailingBytesThrows() {
        var bytes = ControlCodec.encode(.bye)
        bytes.append(0x00)
        XCTAssertThrowsError(try ControlCodec.decode(bytes)) { error in
            XCTAssertEqual(error as? InputCodecError, .trailingBytes)
        }
    }

    func testVideoFrameHeaderRoundtripWithPayload() throws {
        let header = VideoFrameHeader(isKeyframe: true, sequence: 9, ptsMicros: 123_456, width: 1280, height: 800)
        let payload: [UInt8] = [0xAA, 0xBB, 0xCC, 0xDD]
        let framed = header.encoded() + payload

        let (decodedHeader, decodedPayload) = try VideoFrameHeader.decode(framed)
        XCTAssertEqual(decodedHeader, header)
        XCTAssertEqual(decodedPayload, payload)
        XCTAssertEqual(header.encoded().count, VideoFrameHeader.byteCount)
    }

    func testVideoFrameHeaderTruncatedThrows() {
        let header = VideoFrameHeader(isKeyframe: false, sequence: 1, ptsMicros: 0, width: 100, height: 100)
        let short = Array(header.encoded().prefix(10))
        XCTAssertThrowsError(try VideoFrameHeader.decode(short))
    }
}
