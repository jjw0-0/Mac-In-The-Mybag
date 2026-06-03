import XCTest
@testable import SharedCore

/// DG-5 degradation ladder + hysteresis — UT-A1 / UT-A3.
final class AdaptiveBitrateTests: XCTestCase {

    private let good = LinkMetrics(rttMs: 20, lossRate: 0, bandwidthMbps: 50)

    func testStartsAtBestTier() {
        let abr = AdaptiveBitrateController()
        XCTAssertEqual(abr.tierIndex, 0)
        XCTAssertEqual(abr.quality.fps, 60)
        XCTAssertEqual(abr.quality.codec, .h265)
    }

    func testHighRTTDegradesToTier1() {
        var abr = AdaptiveBitrateController()
        let q = abr.update(LinkMetrics(rttMs: 130, lossRate: 0, bandwidthMbps: 50))
        XCTAssertEqual(abr.tierIndex, 1)
        XCTAssertEqual(q.fps, 30)
        XCTAssertEqual(q.codec, .h264) // H.265 → H.264 forced on degrade (UT-A3)
    }

    func testVeryHighRTTDegradesToTier2() {
        var abr = AdaptiveBitrateController()
        let q = abr.update(LinkMetrics(rttMs: 210, lossRate: 0, bandwidthMbps: 50))
        XCTAssertEqual(abr.tierIndex, 2)
        XCTAssertEqual(q.resolutionScale, 0.75, accuracy: 1e-9)
    }

    func testLowBandwidthDegradesToTier3WithInputPriority() {
        var abr = AdaptiveBitrateController()
        let q = abr.update(LinkMetrics(rttMs: 20, lossRate: 0, bandwidthMbps: 1.0))
        XCTAssertEqual(abr.tierIndex, 3)
        XCTAssertEqual(q.fps, 15)
        XCTAssertEqual(q.resolutionScale, 0.5, accuracy: 1e-9)
        XCTAssertTrue(q.prioritizeInput)
    }

    func testHysteresisHoldsNearThreshold() {
        var abr = AdaptiveBitrateController()
        abr.update(LinkMetrics(rttMs: 130, lossRate: 0, bandwidthMbps: 50)) // → T1
        // 110 ms is below the 120 ms degrade threshold but above the 96 ms recovery margin.
        abr.update(LinkMetrics(rttMs: 110, lossRate: 0, bandwidthMbps: 50))
        XCTAssertEqual(abr.tierIndex, 1, "should not flap back up until clearly recovered")
    }

    func testRecoversWhenMetricsClearMargin() {
        var abr = AdaptiveBitrateController()
        abr.update(LinkMetrics(rttMs: 130, lossRate: 0, bandwidthMbps: 50)) // → T1
        abr.update(LinkMetrics(rttMs: 90, lossRate: 0, bandwidthMbps: 50))  // < 96 ms → recover
        XCTAssertEqual(abr.tierIndex, 0)
        XCTAssertEqual(abr.quality.codec, .h265)
    }

    func testRecoveryStepsOneTierAtATime() {
        var abr = AdaptiveBitrateController()
        abr.update(LinkMetrics(rttMs: 20, lossRate: 0, bandwidthMbps: 1.0)) // → T3
        XCTAssertEqual(abr.tierIndex, 3)
        let q = abr.update(good) // good link, but step up only one tier
        XCTAssertEqual(abr.tierIndex, 2)
        XCTAssertEqual(q.resolutionScale, 0.75, accuracy: 1e-9)
    }

    func testMonotonicDegradationNeverImprovesUnderWorseningLink() {
        var abr = AdaptiveBitrateController()
        var lastTier = abr.tierIndex
        for rtt in [50.0, 130.0, 210.0] {
            abr.update(LinkMetrics(rttMs: rtt, lossRate: 0, bandwidthMbps: 50))
            XCTAssertGreaterThanOrEqual(abr.tierIndex, lastTier)
            lastTier = abr.tierIndex
        }
    }
}
