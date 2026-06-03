import Foundation

/// Errors raised while decoding a `SequencedInput` from bytes.
public enum InputCodecError: Error, Equatable {
    case truncated
    case unknownEventType(UInt8)
    case unknownValue(field: String, raw: UInt8)
    case trailingBytes
}

/// Deterministic, compact binary codec for `SequencedInput`.
///
/// Layout (big-endian): `[sequence: u64][type: u8][payload…]`. Doubles are encoded
/// by bit pattern for exact round-trips (UT-I1). Decoding rejects truncated,
/// over-long, or unknown payloads (UT-I3).
public enum InputCodec {

    private static let tagPointerMove: UInt8 = 1
    private static let tagMouseButton: UInt8 = 2
    private static let tagScroll: UInt8      = 3
    private static let tagKey: UInt8         = 4

    public static func encode(_ input: SequencedInput) -> [UInt8] {
        var out: [UInt8] = []
        out.appendBE(input.sequence)

        switch input.event {
        case .pointerMove(let move):
            out.append(tagPointerMove)
            switch move {
            case .absolute(let p):
                out.append(0)
                out.appendBE(p.x.bitPattern)
                out.appendBE(p.y.bitPattern)
            case .relative(let dx, let dy):
                out.append(1)
                out.appendBE(dx.bitPattern)
                out.appendBE(dy.bitPattern)
            }
        case .mouseButton(let button, let action):
            out.append(tagMouseButton)
            out.append(button.rawValue)
            out.append(action.rawValue)
        case .scroll(let s):
            out.append(tagScroll)
            out.appendBE(s.dx.bitPattern)
            out.appendBE(s.dy.bitPattern)
            out.append(s.isMomentum ? 1 : 0)
        case .key(let k):
            out.append(tagKey)
            out.appendBE(k.keyCode)
            out.append(k.action.rawValue)
            out.appendBE(k.modifiers.rawValue)
        }
        return out
    }

    public static func decode(_ bytes: [UInt8]) throws -> SequencedInput {
        var reader = ByteReader(bytes)
        let sequence = try reader.u64()
        let tag = try reader.u8()

        let event: InputEvent
        switch tag {
        case tagPointerMove:
            let kind = try reader.u8()
            let x = Double(bitPattern: try reader.u64())
            let y = Double(bitPattern: try reader.u64())
            switch kind {
            case 0: event = .pointerMove(.absolute(LogicalPoint(x: x, y: y)))
            case 1: event = .pointerMove(.relative(dx: x, dy: y))
            default: throw InputCodecError.unknownValue(field: "pointerMoveKind", raw: kind)
            }
        case tagMouseButton:
            let rawButton = try reader.u8()
            let rawAction = try reader.u8()
            guard let button = MouseButton(rawValue: rawButton) else {
                throw InputCodecError.unknownValue(field: "mouseButton", raw: rawButton)
            }
            guard let action = ButtonAction(rawValue: rawAction) else {
                throw InputCodecError.unknownValue(field: "buttonAction", raw: rawAction)
            }
            event = .mouseButton(button, action)
        case tagScroll:
            let dx = Double(bitPattern: try reader.u64())
            let dy = Double(bitPattern: try reader.u64())
            let momentum = try reader.u8()
            event = .scroll(Scroll(dx: dx, dy: dy, isMomentum: momentum != 0))
        case tagKey:
            let code = try reader.u16()
            let rawAction = try reader.u8()
            let mods = try reader.u32()
            guard let action = ButtonAction(rawValue: rawAction) else {
                throw InputCodecError.unknownValue(field: "buttonAction", raw: rawAction)
            }
            event = .key(KeyEvent(keyCode: code, action: action, modifiers: Modifiers(rawValue: mods)))
        default:
            throw InputCodecError.unknownEventType(tag)
        }

        guard reader.atEnd else { throw InputCodecError.trailingBytes }
        return SequencedInput(sequence: sequence, event: event)
    }
}

// MARK: - Big-endian byte helpers

extension Array where Element == UInt8 {
    mutating func appendBE(_ v: UInt16) {
        append(UInt8(truncatingIfNeeded: v >> 8))
        append(UInt8(truncatingIfNeeded: v))
    }
    mutating func appendBE(_ v: UInt32) {
        for shift in stride(from: 24, through: 0, by: -8) {
            append(UInt8(truncatingIfNeeded: v >> UInt32(shift)))
        }
    }
    mutating func appendBE(_ v: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            append(UInt8(truncatingIfNeeded: v >> UInt64(shift)))
        }
    }
    mutating func appendUUID(_ uuid: UUID) {
        let u = uuid.uuid
        append(contentsOf: [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
                            u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15])
    }
}

/// Sequential big-endian reader that throws on underflow.
struct ByteReader {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    var atEnd: Bool { offset == bytes.count }

    mutating func u8() throws -> UInt8 {
        guard offset + 1 <= bytes.count else { throw InputCodecError.truncated }
        defer { offset += 1 }
        return bytes[offset]
    }
    mutating func u16() throws -> UInt16 {
        guard offset + 2 <= bytes.count else { throw InputCodecError.truncated }
        defer { offset += 2 }
        return (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
    }
    mutating func u32() throws -> UInt32 {
        guard offset + 4 <= bytes.count else { throw InputCodecError.truncated }
        defer { offset += 4 }
        var value: UInt32 = 0
        for i in 0..<4 { value = (value << 8) | UInt32(bytes[offset + i]) }
        return value
    }
    mutating func u64() throws -> UInt64 {
        guard offset + 8 <= bytes.count else { throw InputCodecError.truncated }
        defer { offset += 8 }
        var value: UInt64 = 0
        for i in 0..<8 { value = (value << 8) | UInt64(bytes[offset + i]) }
        return value
    }
    mutating func take(_ count: Int) throws -> [UInt8] {
        guard count >= 0, offset + count <= bytes.count else { throw InputCodecError.truncated }
        defer { offset += count }
        return Array(bytes[offset ..< offset + count])
    }
    mutating func uuid() throws -> UUID {
        let b = try take(16)
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}
