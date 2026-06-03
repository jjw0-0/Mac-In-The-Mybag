import Foundation

/// 논리 좌표(pt). AC9 / DG-10 — 좌표 오차 단위는 pt(스케일 독립).
public struct LogicalPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// 물리 픽셀 좌표(px).
public struct PhysicalPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// 디스플레이 스케일 팩터(Retina 1x/2x/3x, ProMotion 포함).
public struct DisplayScale: Equatable, Sendable {
    public let factor: Double
    public init(factor: Double) {
        precondition(factor > 0, "scale factor must be > 0")
        self.factor = factor
    }
    public static let nonRetina = DisplayScale(factor: 1.0)
    public static let retina2x  = DisplayScale(factor: 2.0)
    public static let retina3x  = DisplayScale(factor: 3.0)
}

/// 좌표 변환 — DG-10(단위 pt) 기준. 논리 pt ↔ 물리 px.
/// AC9 검증(UT-C1 / UT-C2)의 대상.
public enum CoordinateMapper {
    public static func toPhysical(_ p: LogicalPoint, scale: DisplayScale) -> PhysicalPoint {
        PhysicalPoint(x: p.x * scale.factor, y: p.y * scale.factor)
    }
    public static func toLogical(_ p: PhysicalPoint, scale: DisplayScale) -> LogicalPoint {
        LogicalPoint(x: p.x / scale.factor, y: p.y / scale.factor)
    }
    /// 두 논리 좌표 간 pt 오차(유클리드 거리). AC9 허용 ≤2pt(목표 ≤1pt) 판정에 사용.
    public static func errorPt(_ a: LogicalPoint, _ b: LogicalPoint) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
