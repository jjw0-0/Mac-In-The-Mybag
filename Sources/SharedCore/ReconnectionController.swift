import Foundation

/// Drives reconnection timing: exponential backoff with a bounded number of attempts
/// (F9 / AC8). Pure decision logic — the caller performs the actual reconnect.
public struct ReconnectionController: Sendable {
    public let backoff: ExponentialBackoff
    public let maxAttempts: Int
    public private(set) var attempt: Int = 0

    public init(backoff: ExponentialBackoff = ExponentialBackoff(), maxAttempts: Int = 8) {
        self.backoff = backoff
        self.maxAttempts = maxAttempts
    }

    /// Call on a successful connection to clear the attempt counter.
    public mutating func reset() {
        attempt = 0
    }

    /// Advances to the next attempt and returns its delay, or nil once attempts are exhausted.
    public mutating func nextDelay() -> TimeInterval? {
        guard attempt < maxAttempts else { return nil }
        attempt += 1
        return backoff.delay(forAttempt: attempt)
    }
}
