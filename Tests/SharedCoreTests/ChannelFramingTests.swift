import XCTest
@testable import SharedCore

/// Channel framing + fragmentation-tolerant decoding.
final class ChannelFramingTests: XCTestCase {

    func testFrameAndDecodeRoundtrip() {
        let payload: [UInt8] = [1, 2, 3, 4, 5]
        var decoder = FrameDecoder()
        decoder.push(ChannelFraming.frame(.input, payload))
        let message = decoder.next()
        XCTAssertEqual(message, FramedMessage(channel: .input, payload: payload))
        XCTAssertNil(decoder.next())
    }

    func testTwoMessagesBackToBack() {
        var bytes = ChannelFraming.frame(.control, [0xAA])
        bytes += ChannelFraming.frame(.video, [0xBB, 0xCC])
        var decoder = FrameDecoder()
        decoder.push(bytes)
        XCTAssertEqual(decoder.next(), FramedMessage(channel: .control, payload: [0xAA]))
        XCTAssertEqual(decoder.next(), FramedMessage(channel: .video, payload: [0xBB, 0xCC]))
        XCTAssertNil(decoder.next())
    }

    func testFragmentedDelivery() {
        let framed = ChannelFraming.frame(.video, [10, 20, 30, 40])
        var decoder = FrameDecoder()
        // Deliver one byte at a time; only the final byte completes the message.
        for (i, byte) in framed.enumerated() {
            decoder.push([byte])
            if i < framed.count - 1 {
                XCTAssertNil(decoder.next(), "incomplete frame should not yield a message")
            }
        }
        XCTAssertEqual(decoder.next(), FramedMessage(channel: .video, payload: [10, 20, 30, 40]))
    }

    func testEmptyPayload() {
        var decoder = FrameDecoder()
        decoder.push(ChannelFraming.frame(.control, []))
        XCTAssertEqual(decoder.next(), FramedMessage(channel: .control, payload: []))
    }
}
