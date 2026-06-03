import Foundation

/// 가상/물리 디스플레이 추상화 — G-Sleep 경로 (iii) 격리(follow-up #2).
///
/// v1: `CGVirtualDisplayProvider` (Developer-ID + GitHub Releases 배포)
/// v2: `PhysicalDisplayProvider` (하드웨어 더미 플러그, App Store)
///
/// 구체 구현은 플랫폼 프레임워크에 의존하므로 `MacOSAgent`에 둔다. SharedCore는 **계약만** 정의.
public protocol DisplayProvider {
    /// 캡처 대상 디스플레이를 생성/확보하고 핸들을 반환.
    func makeDisplay(width: Int, height: Int, refreshHz: Double) throws -> DisplayHandle
    /// 디스플레이 해제.
    func release(_ handle: DisplayHandle)
}

/// 생성된 디스플레이 핸들.
public struct DisplayHandle: Equatable, Sendable {
    public let displayID: UInt32
    public let width: Int
    public let height: Int
    public init(displayID: UInt32, width: Int, height: Int) {
        self.displayID = displayID
        self.width = width
        self.height = height
    }
}

/// DisplayProvider 오류.
public enum DisplayProviderError: Error, Equatable {
    case creationFailed
    case unsupported
}
