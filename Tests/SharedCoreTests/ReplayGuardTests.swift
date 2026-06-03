import XCTest
@testable import SharedCore

/// Monotonic sequence + replay defense — UT-I6 / SEC-7.
final class ReplayGuardTests: XCTestCase {

    func testAcceptsStrictlyIncreasing() {
        var guardState = ReplayGuard()
        XCTAssertTrue(guardState.accept(1))
        XCTAssertTrue(guardState.accept(2))
        XCTAssertTrue(guardState.accept(3))
        XCTAssertEqual(guardState.lastAccepted, 3)
    }

    func testRejectsDuplicate() {
        var guardState = ReplayGuard()
        XCTAssertTrue(guardState.accept(5))
        XCTAssertFalse(guardState.accept(5)) // replayed
        XCTAssertEqual(guardState.lastAccepted, 5)
    }

    func testRejectsRegression() {
        var guardState = ReplayGuard()
        XCTAssertTrue(guardState.accept(10))
        XCTAssertFalse(guardState.accept(9)) // stale / out of order
        XCTAssertEqual(guardState.lastAccepted, 10)
    }

    func testAllowsGapsFromDroppedPackets() {
        var guardState = ReplayGuard()
        XCTAssertTrue(guardState.accept(1))
        XCTAssertTrue(guardState.accept(5)) // 2…4 dropped, still newer
        XCTAssertEqual(guardState.lastAccepted, 5)
    }

    func testSequencerIsMonotonic() {
        var sequencer = InputSequencer()
        let first = sequencer.stamp(.mouseButton(.left, .down))
        let second = sequencer.stamp(.mouseButton(.left, .up))
        XCTAssertEqual(first.sequence, 1)
        XCTAssertEqual(second.sequence, 2)
        XCTAssertGreaterThan(second.sequence, first.sequence)
    }

    func testEndToEndReplayIsRejected() {
        var sequencer = InputSequencer()
        var guardState = ReplayGuard()
        let command = sequencer.stamp(.scroll(Scroll(dx: 0, dy: 10)))
        XCTAssertTrue(guardState.accept(command))  // first delivery
        XCTAssertFalse(guardState.accept(command)) // replayed identical command
    }
}
