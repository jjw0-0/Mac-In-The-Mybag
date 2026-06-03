import XCTest
@testable import SharedCore

/// 좌표 변환 — AC9 / DG-10(단위 pt). UT-C1 / UT-C2.
final class GeometryTests: XCTestCase {

    func testToPhysicalRetina2x() {
        let p = CoordinateMapper.toPhysical(LogicalPoint(x: 100, y: 50), scale: .retina2x)
        XCTAssertEqual(p, PhysicalPoint(x: 200, y: 100))
    }

    func testNonRetinaIsIdentity() {
        let p = LogicalPoint(x: 7, y: 9)
        XCTAssertEqual(CoordinateMapper.toPhysical(p, scale: .nonRetina), PhysicalPoint(x: 7, y: 9))
    }

    func testRoundTripRetina3x() {
        let original = LogicalPoint(x: 12.5, y: 33.0)
        let physical = CoordinateMapper.toPhysical(original, scale: .retina3x)
        let back = CoordinateMapper.toLogical(physical, scale: .retina3x)
        XCTAssertEqual(back.x, original.x, accuracy: 1e-9)
        XCTAssertEqual(back.y, original.y, accuracy: 1e-9)
    }

    func testErrorPtWithinAC9Tolerance() {
        // AC9 허용 ≤2pt
        let a = LogicalPoint(x: 100, y: 100)
        let b = LogicalPoint(x: 101, y: 100.5)
        XCTAssertLessThanOrEqual(CoordinateMapper.errorPt(a, b), 2.0)
    }
}
