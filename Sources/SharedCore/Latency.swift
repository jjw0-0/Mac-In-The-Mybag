import Foundation

/// Latency sample aggregator for the L2 instrumentation harness (F-L2).
///
/// Records end-to-end latency samples (microseconds) and reports the statistics the
/// acceptance criteria are stated in — median and p95 (AC1/AC3).
public struct LatencyAggregator: Sendable {
    private var samplesMicros: [Double] = []

    public init() {}

    public mutating func record(_ micros: Double) {
        samplesMicros.append(micros)
    }

    public var count: Int { samplesMicros.count }
    public var mean: Double? { count > 0 ? samplesMicros.reduce(0, +) / Double(count) : nil }
    public var min: Double? { samplesMicros.min() }
    public var max: Double? { samplesMicros.max() }
    public var median: Double? { percentile(50) }
    public var p95: Double? { percentile(95) }

    /// Nearest-rank percentile (0…100). Returns nil when there are no samples.
    public func percentile(_ p: Double) -> Double? {
        guard !samplesMicros.isEmpty else { return nil }
        let sorted = samplesMicros.sorted()
        let rank = Int((p / 100.0 * Double(sorted.count)).rounded(.up))
        let index = Swift.min(Swift.max(rank - 1, 0), sorted.count - 1)
        return sorted[index]
    }
}

/// Echo-marker latency math (L2 method).
public enum L2 {
    /// End-to-end latency (µs) from an echo marker: the time between stamping an input
    /// and detecting the corresponding marker frame, minus the fixed render→detect
    /// calibration overhead. Uses Double arithmetic to tolerate small clock skew.
    public static func latencyMicros(sentMicros: UInt64,
                                     detectedMicros: UInt64,
                                     calibrationMicros: Double = 0) -> Double {
        Double(detectedMicros) - Double(sentMicros) - calibrationMicros
    }
}
