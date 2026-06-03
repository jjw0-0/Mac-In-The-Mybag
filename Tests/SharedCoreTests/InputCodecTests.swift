import XCTest
@testable import SharedCore

/// Input codec round-trips and malformed-input rejection — UT-I1 / UT-I3 / UT-I5.
final class InputCodecTests: XCTestCase {

    private func assertRoundtrip(_ input: SequencedInput,
                                 file: StaticString = #filePath, line: UInt = #line) throws {
        let bytes = InputCodec.encode(input)
        let decoded = try InputCodec.decode(bytes)
        XCTAssertEqual(decoded, input, file: file, line: line)
    }

    func testPointerMoveAbsoluteRoundtrip() throws {
        try assertRoundtrip(.init(sequence: 1, event: .pointerMove(.absolute(LogicalPoint(x: 12.5, y: -7.25)))))
    }

    func testPointerMoveRelativeRoundtrip() throws {
        try assertRoundtrip(.init(sequence: 2, event: .pointerMove(.relative(dx: -3.5, dy: 4.0))))
    }

    func testMouseButtonRoundtrip() throws {
        try assertRoundtrip(.init(sequence: 3, event: .mouseButton(.right, .down)))
    }

    func testScrollRoundtrip() throws {
        try assertRoundtrip(.init(sequence: 4, event: .scroll(Scroll(dx: 0.0, dy: -120.75, isMomentum: true))))
    }

    func testKeyRoundtripWithModifiers() throws {
        try assertRoundtrip(.init(sequence: 5, event: .key(KeyEvent(keyCode: 0x0B, action: .down, modifiers: [.command, .shift]))))
    }

    func testBoundaryValues() throws {
        try assertRoundtrip(.init(sequence: .max,
                                  event: .pointerMove(.absolute(LogicalPoint(x: .greatestFiniteMagnitude,
                                                                             y: -.greatestFiniteMagnitude)))))
        try assertRoundtrip(.init(sequence: 0,
                                  event: .key(KeyEvent(keyCode: .max, action: .up, modifiers: Modifiers(rawValue: .max)))))
    }

    func testDecodeTruncatedThrows() {
        let bytes = InputCodec.encode(.init(sequence: 9, event: .mouseButton(.left, .up)))
        XCTAssertThrowsError(try InputCodec.decode(Array(bytes.dropLast())))
    }

    func testDecodeUnknownTypeThrows() {
        let bytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 1, 0xFF] // seq=1, type=0xFF
        XCTAssertThrowsError(try InputCodec.decode(bytes)) { error in
            XCTAssertEqual(error as? InputCodecError, .unknownEventType(0xFF))
        }
    }

    func testDecodeTrailingBytesThrows() {
        var bytes = InputCodec.encode(.init(sequence: 7, event: .mouseButton(.middle, .down)))
        bytes.append(0x00)
        XCTAssertThrowsError(try InputCodec.decode(bytes)) { error in
            XCTAssertEqual(error as? InputCodecError, .trailingBytes)
        }
    }
}
