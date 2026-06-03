import XCTest
@testable import SharedCore

/// Reconnection backoff — UT-S3 / AC8.
final class BackoffTests: XCTestCase {

    func testExponentialGrowthThenCap() {
        let backoff = ExponentialBackoff(base: 0.25, cap: 5.0, factor: 2.0)
        XCTAssertEqual(backoff.delay(forAttempt: 0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(backoff.delay(forAttempt: 1), 0.25, accuracy: 1e-9)
        XCTAssertEqual(backoff.delay(forAttempt: 2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(backoff.delay(forAttempt: 3), 1.0, accuracy: 1e-9)
        XCTAssertEqual(backoff.delay(forAttempt: 4), 2.0, accuracy: 1e-9)
        XCTAssertEqual(backoff.delay(forAttempt: 100), 5.0, accuracy: 1e-9) // capped
    }

    func testNeverExceedsCap() {
        let backoff = ExponentialBackoff(base: 1.0, cap: 3.0, factor: 3.0)
        for attempt in 0...20 {
            XCTAssertLessThanOrEqual(backoff.delay(forAttempt: attempt), 3.0)
        }
    }
}
