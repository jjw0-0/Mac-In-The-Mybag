#if os(macOS)
import XCTest
import CoreGraphics
import SharedCore
@testable import MacOSAgent

/// Pure mapping helpers in the input injector (F3/F4). Posting itself needs Accessibility
/// and is covered by manual/integration testing.
final class InputInjectorTests: XCTestCase {

    func testModifierFlagMapping() {
        let flags = InputInjector.cgFlags([.command, .shift])
        XCTAssertTrue(flags.contains(.maskCommand))
        XCTAssertTrue(flags.contains(.maskShift))
        XCTAssertFalse(flags.contains(.maskControl))
    }

    func testEmptyModifiers() {
        XCTAssertEqual(InputInjector.cgFlags([]), [])
    }

    func testClampKeepsPointInsideBounds() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 80)
        XCTAssertEqual(InputInjector.clamp(CGPoint(x: 150, y: -10), to: bounds), CGPoint(x: 100, y: 0))
        XCTAssertEqual(InputInjector.clamp(CGPoint(x: 40, y: 40), to: bounds), CGPoint(x: 40, y: 40))
    }

    func testClampedInt32HandlesNaNAndOverflow() {
        XCTAssertEqual(InputInjector.clampedInt32(.nan), 0)
        XCTAssertEqual(InputInjector.clampedInt32(1e18), Int32.max)
        XCTAssertEqual(InputInjector.clampedInt32(-1e18), Int32.min)
        XCTAssertEqual(InputInjector.clampedInt32(12.4), 12)
    }
}
#endif
