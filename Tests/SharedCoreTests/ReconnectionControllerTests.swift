import XCTest
@testable import SharedCore

/// Reconnection backoff schedule + exhaustion (F9 / AC8 / UT-S3).
final class ReconnectionControllerTests: XCTestCase {

    func testBackoffScheduleThenExhaustion() throws {
        var controller = ReconnectionController(
            backoff: ExponentialBackoff(base: 0.25, cap: 5.0, factor: 2.0),
            maxAttempts: 8)

        let expected: [TimeInterval] = [0.25, 0.5, 1.0, 2.0, 4.0, 5.0, 5.0, 5.0]
        for value in expected {
            XCTAssertEqual(try XCTUnwrap(controller.nextDelay()), value, accuracy: 1e-9)
        }
        XCTAssertNil(controller.nextDelay(), "should give up after maxAttempts")
        XCTAssertEqual(controller.attempt, 8)
    }

    func testResetRestartsSchedule() {
        var controller = ReconnectionController(maxAttempts: 3)
        _ = controller.nextDelay()
        _ = controller.nextDelay()
        controller.reset()
        XCTAssertEqual(controller.attempt, 0)
        XCTAssertNotNil(controller.nextDelay())
        XCTAssertEqual(controller.attempt, 1)
    }
}
