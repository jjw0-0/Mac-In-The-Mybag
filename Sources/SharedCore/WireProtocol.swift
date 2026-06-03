import Foundation

/// Logical channels multiplexed over the transport (separate QUIC streams).
public enum Channel: UInt8, Equatable, Sendable {
    case control = 0
    case video = 1
    case input = 2
}

/// Control-plane messages exchanged on the control channel.
public enum ControlMessage: Equatable, Sendable {
    case hello(deviceID: UUID)
    case helloAck(sessionToken: UInt64)
    case ping(nonce: UInt64, sentMicros: UInt64)
    case pong(nonce: UInt64, sentMicros: UInt64)
    case requestKeyframe
    case setQuality(StreamQuality)
    case resume(sessionToken: UInt64, lastInputSequence: UInt64)
    case bye
}

/// Deterministic binary codec for `ControlMessage`. (Reuses `InputCodecError` and the
/// shared big-endian `ByteReader`.)
public enum ControlCodec {
    public static func encode(_ message: ControlMessage) -> [UInt8] {
        var out: [UInt8] = []
        switch message {
        case .hello(let id):
            out.append(1); out.appendUUID(id)
        case .helloAck(let token):
            out.append(2); out.appendBE(token)
        case .ping(let nonce, let sent):
            out.append(3); out.appendBE(nonce); out.appendBE(sent)
        case .pong(let nonce, let sent):
            out.append(4); out.appendBE(nonce); out.appendBE(sent)
        case .requestKeyframe:
            out.append(5)
        case .setQuality(let q):
            out.append(6)
            out.appendBE(UInt16(clamping: q.fps))
            out.appendBE(q.resolutionScale.bitPattern)
            out.append(q.codec == .h265 ? 1 : 0)
            out.append(q.prioritizeInput ? 1 : 0)
        case .resume(let token, let seq):
            out.append(7); out.appendBE(token); out.appendBE(seq)
        case .bye:
            out.append(8)
        }
        return out
    }

    public static func decode(_ bytes: [UInt8]) throws -> ControlMessage {
        var reader = ByteReader(bytes)
        let tag = try reader.u8()
        let message: ControlMessage
        switch tag {
        case 1: message = .hello(deviceID: try reader.uuid())
        case 2: message = .helloAck(sessionToken: try reader.u64())
        case 3: message = .ping(nonce: try reader.u64(), sentMicros: try reader.u64())
        case 4: message = .pong(nonce: try reader.u64(), sentMicros: try reader.u64())
        case 5: message = .requestKeyframe
        case 6:
            let fps = Int(try reader.u16())
            let scale = Double(bitPattern: try reader.u64())
            let codec: VideoCodec = (try reader.u8()) == 1 ? .h265 : .h264
            let prioritize = (try reader.u8()) != 0
            message = .setQuality(StreamQuality(fps: fps, resolutionScale: scale,
                                                codec: codec, prioritizeInput: prioritize))
        case 7: message = .resume(sessionToken: try reader.u64(), lastInputSequence: try reader.u64())
        case 8: message = .bye
        default: throw InputCodecError.unknownEventType(tag)
        }
        guard reader.atEnd else { throw InputCodecError.trailingBytes }
        return message
    }
}

/// Fixed-size header prefixing each encoded video frame on the video channel.
public struct VideoFrameHeader: Equatable, Sendable {
    public var isKeyframe: Bool
    public var sequence: UInt64
    public var ptsMicros: UInt64
    public var width: UInt16
    public var height: UInt16

    public init(isKeyframe: Bool, sequence: UInt64, ptsMicros: UInt64, width: UInt16, height: UInt16) {
        self.isKeyframe = isKeyframe
        self.sequence = sequence
        self.ptsMicros = ptsMicros
        self.width = width
        self.height = height
    }

    /// Encoded header length in bytes: 1 + 8 + 8 + 2 + 2.
    public static let byteCount = 21

    public func encoded() -> [UInt8] {
        var out: [UInt8] = []
        out.append(isKeyframe ? 1 : 0)
        out.appendBE(sequence)
        out.appendBE(ptsMicros)
        out.appendBE(width)
        out.appendBE(height)
        return out
    }

    /// Splits a framed video packet into its header and payload (the encoded picture).
    public static func decode(_ bytes: [UInt8]) throws -> (header: VideoFrameHeader, payload: [UInt8]) {
        guard bytes.count >= byteCount else { throw InputCodecError.truncated }
        var reader = ByteReader(bytes)
        let isKeyframe = try reader.u8() != 0
        let sequence = try reader.u64()
        let ptsMicros = try reader.u64()
        let width = try reader.u16()
        let height = try reader.u16()
        let payload = Array(bytes.dropFirst(byteCount))
        return (VideoFrameHeader(isKeyframe: isKeyframe, sequence: sequence,
                                 ptsMicros: ptsMicros, width: width, height: height), payload)
    }
}
