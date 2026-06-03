import Foundation

/// Rejects duplicate or out-of-order input commands (replay defense — UT-I6 / SEC-7).
///
/// Accepts only **strictly increasing** sequence numbers. Gaps (from packets dropped
/// in transit) are allowed; a repeated or regressing sequence is rejected.
public struct ReplayGuard: Sendable {
    public private(set) var lastAccepted: UInt64

    public init(lastAccepted: UInt64 = 0) {
        self.lastAccepted = lastAccepted
    }

    /// Returns `true` and advances state if `sequence` is newer; `false` otherwise.
    @discardableResult
    public mutating func accept(_ sequence: UInt64) -> Bool {
        guard sequence > lastAccepted else { return false }
        lastAccepted = sequence
        return true
    }

    @discardableResult
    public mutating func accept(_ input: SequencedInput) -> Bool {
        accept(input.sequence)
    }
}

/// Stamps outgoing input with a monotonically increasing sequence (sender side).
public struct InputSequencer: Sendable {
    private var next: UInt64

    public init(start: UInt64 = 1) {
        self.next = start
    }

    public mutating func stamp(_ event: InputEvent) -> SequencedInput {
        defer { next &+= 1 }
        return SequencedInput(sequence: next, event: event)
    }
}
