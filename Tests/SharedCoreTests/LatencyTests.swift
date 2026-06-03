import XCTest
@testable import SharedCore

/// L2 latency statistics + echo-marker math (F-L2, AC1/AC3).
final class LatencyTests: XCTestCase {

    func testStatisticsOverKnownSamples() {
        var agg = LatencyAggregator()
        for v in [10.0, 20, 30, 40, 50] { agg.record(v) }
        XCTAssertEqual(agg.count, 5)
        XCTAssertEqual(agg.median, 30)
        XCTAssertEqual(agg.p95, 50)
        XCTAssertEqual(agg.mean, 30)
        XCTAssertEqual(agg.min, 10)
        XCTAssertEqual(agg.max, 50)
    }

    func testEmptyAggregatorReturnsNil() {
        let agg = LatencyAggregator()
        XCTAssertNil(agg.median)
        XCTAssertNil(agg.p95)
        XCTAssertNil(agg.mean)
    }

    func testPercentileNearestRank() {
        var agg = LatencyAggregator()
        for v in stride(from: 1.0, through: 100.0, by: 1.0) { agg.record(v) }
        XCTAssertEqual(agg.percentile(95), 95)
        XCTAssertEqual(agg.percentile(50), 50)
        XCTAssertEqual(agg.percentile(100), 100)
    }

    func testEchoMarkerLatency() {
        let micros = L2.latencyMicros(sentMicros: 1_000, detectedMicros: 1_080, calibrationMicros: 10)
        XCTAssertEqual(micros, 70, accuracy: 1e-9)
    }
}
