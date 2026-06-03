import XCTest
@testable import SharedCore

/// Trackpad gesture → input mapping (G3, DG-6).
final class GestureInterpreterTests: XCTestCase {

    func testPanMovesCursorRelatively() {
        XCTAssertEqual(GestureInterpreter.translate(.panMoved(dx: 3, dy: -4)),
                       [.pointerMove(.relative(dx: 3, dy: -4))])
    }

    func testTapIsLeftClick() {
        XCTAssertEqual(GestureInterpreter.translate(.tap),
                       [.mouseButton(.left, .down), .mouseButton(.left, .up)])
    }

    func testTwoFingerTapIsRightClick() {
        XCTAssertEqual(GestureInterpreter.translate(.twoFingerTap),
                       [.mouseButton(.right, .down), .mouseButton(.right, .up)])
    }

    func testTwoFingerScroll() {
        XCTAssertEqual(GestureInterpreter.translate(.twoFingerScroll(dx: 0, dy: 12)),
                       [.scroll(Scroll(dx: 0, dy: 12))])
    }

    func testLongPressDrag() {
        XCTAssertEqual(GestureInterpreter.translate(.longPressDragBegan), [.mouseButton(.left, .down)])
        XCTAssertEqual(GestureInterpreter.translate(.longPressDragEnded), [.mouseButton(.left, .up)])
    }
}
