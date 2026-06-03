import Foundation

/// Video codec selection.
public enum VideoCodec: Equatable, Sendable {
    case h264
    case h265
}

/// A discrete streaming quality level.
public struct StreamQuality: Equatable, Sendable {
    public let fps: Int
    public let resolutionScale: Double
    public let codec: VideoCodec
    /// When true, the input channel is prioritized over video under bandwidth starvation.
    public let prioritizeInput: Bool

    public init(fps: Int, resolutionScale: Double, codec: VideoCodec, prioritizeInput: Bool) {
        self.fps = fps
        self.resolutionScale = resolutionScale
        self.codec = codec
        self.prioritizeInput = prioritizeInput
    }
}

/// Sampled link conditions feeding the adaptive controller.
public struct LinkMetrics: Equatable, Sendable {
    public var rttMs: Double
    public var lossRate: Double      // 0.0 … 1.0
    public var bandwidthMbps: Double

    public init(rttMs: Double, lossRate: Double, bandwidthMbps: Double) {
        self.rttMs = rttMs
        self.lossRate = lossRate
        self.bandwidthMbps = bandwidthMbps
    }
}

/// Adaptive bitrate/quality controller — the implementation of the DG-5 degradation
/// ladder with hysteresis (UT-A1 / UT-A3).
///
/// Ladder (best → worst):
///  - T0: 60 fps · 1.00× · H.265-eligible
///  - T1: 30 fps · 1.00× · H.264          (RTT > 120 ms or loss > 5%)
///  - T2: 30 fps · 0.75× · H.264          (RTT > 200 ms)
///  - T3: 15 fps · 0.50× · H.264 · input-priority (bandwidth < 1.5 Mbps)
///
/// Degradation uses the nominal thresholds and is applied immediately. Recovery
/// (stepping back up) requires metrics to clear the thresholds by a 20% margin and
/// advances one tier at a time, so quality does not flap around a threshold.
public struct AdaptiveBitrateController: Sendable {

    public static let tiers: [StreamQuality] = [
        StreamQuality(fps: 60, resolutionScale: 1.00, codec: .h265, prioritizeInput: false),
        StreamQuality(fps: 30, resolutionScale: 1.00, codec: .h264, prioritizeInput: false),
        StreamQuality(fps: 30, resolutionScale: 0.75, codec: .h264, prioritizeInput: false),
        StreamQuality(fps: 15, resolutionScale: 0.50, codec: .h264, prioritizeInput: true),
    ]

    public private(set) var tierIndex: Int

    public init(tierIndex: Int = 0) {
        self.tierIndex = min(max(tierIndex, 0), Self.tiers.count - 1)
    }

    public var quality: StreamQuality { Self.tiers[tierIndex] }

    /// Worst tier demanded by the metrics. `rttScale`/`bwScale` tighten thresholds for
    /// recovery hysteresis (rttScale < 1 and bwScale > 1 make recovery stricter).
    static func demandedTier(_ m: LinkMetrics, rttScale: Double, bwScale: Double) -> Int {
        var tier = 0
        if m.rttMs > 120 * rttScale || m.lossRate > 0.05 * rttScale { tier = max(tier, 1) }
        if m.rttMs > 200 * rttScale { tier = max(tier, 2) }
        if m.bandwidthMbps < 1.5 * bwScale { tier = max(tier, 3) }
        return tier
    }

    /// Feeds new metrics and returns the resulting quality.
    @discardableResult
    public mutating func update(_ metrics: LinkMetrics) -> StreamQuality {
        let degradeTarget = Self.demandedTier(metrics, rttScale: 1.0, bwScale: 1.0)
        if degradeTarget > tierIndex {
            tierIndex = degradeTarget                       // degrade immediately
        } else {
            // Recover only when metrics clear thresholds by a 20% margin, one tier at a time.
            let recoverTarget = Self.demandedTier(metrics, rttScale: 0.8, bwScale: 1.2)
            if recoverTarget < tierIndex { tierIndex -= 1 }
        }
        return quality
    }
}
