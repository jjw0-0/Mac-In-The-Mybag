import Foundation

/// Exponential backoff with a ceiling, for reconnection attempts (UT-S3, AC8).
///
/// `delay(forAttempt:)` is `min(base · factor^(attempt-1), cap)`; attempt 0 yields 0.
public struct ExponentialBackoff: Sendable {
    public let base: TimeInterval
    public let cap: TimeInterval
    public let factor: Double

    public init(base: TimeInterval = 0.25, cap: TimeInterval = 5.0, factor: Double = 2.0) {
        self.base = base
        self.cap = cap
        self.factor = factor
    }

    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let raw = base * pow(factor, Double(attempt - 1))
        return Swift.min(raw, cap)
    }
}
