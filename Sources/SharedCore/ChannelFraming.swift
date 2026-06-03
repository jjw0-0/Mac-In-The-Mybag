import Foundation

/// A complete framed message: a channel tag plus its payload.
public struct FramedMessage: Equatable, Sendable {
    public let channel: Channel
    public let payload: [UInt8]
    public init(channel: Channel, payload: [UInt8]) {
        self.channel = channel
        self.payload = payload
    }
}

/// Length-prefixed channel framing carried over a single ordered connection:
/// `[channel: u8][length: u32][payload]`. (Multiplexed QUIC streams can replace this
/// later behind the `Transport` protocol; the framing keeps the wire self-describing.)
public enum ChannelFraming {
    public static func frame(_ channel: Channel, _ payload: [UInt8]) -> [UInt8] {
        var out: [UInt8] = [channel.rawValue]
        out.appendBE(UInt32(truncatingIfNeeded: payload.count))
        out.append(contentsOf: payload)
        return out
    }
}

/// Accumulates received bytes and yields whole framed messages as they complete,
/// tolerating arbitrary fragmentation/coalescing from the transport.
public struct FrameDecoder {
    private var buffer: [UInt8] = []
    private static let headerSize = 5

    public init() {}

    public mutating func push(_ bytes: [UInt8]) {
        buffer.append(contentsOf: bytes)
    }

    /// Returns the next complete message, or nil if more bytes are needed.
    public mutating func next() -> FramedMessage? {
        guard buffer.count >= Self.headerSize else { return nil }
        let length =
            (UInt32(buffer[1]) << 24) |
            (UInt32(buffer[2]) << 16) |
            (UInt32(buffer[3]) << 8) |
             UInt32(buffer[4])
        let total = Self.headerSize + Int(length)
        guard buffer.count >= total else { return nil }

        let channel = Channel(rawValue: buffer[0]) ?? .control
        let payload = Array(buffer[Self.headerSize ..< total])
        buffer.removeFirst(total)
        return FramedMessage(channel: channel, payload: payload)
    }
}
