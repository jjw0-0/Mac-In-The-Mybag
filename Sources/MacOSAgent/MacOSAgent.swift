import Foundation

/// macOSAgent — 모듈 자리표시(플랫폼 무관 부분).
/// 실제 구현은 아래 `#if os(macOS)` 블록에서 컴파일된다.
public enum MacOSAgentModule {
    public static let platformGuarded = true
}

#if os(macOS)
import SharedCore

/// macOSAgent — 화면 캡처/인코딩 · CGEvent 주입 · wake 유지 · 권한 관리.
///
/// 확정 스택: B1 SCK + VideoToolbox(H.264 기본) / C1 CGEvent(**C2 영구 배제, DG-4**) /
/// G-Sleep 경로 (iii). `DisplayProvider` 구체 구현(CGVirtualDisplayProvider)이
/// 다음 단계에서 이 타깃에 들어온다(kill_gate_poc에서 격리 추출).
public enum MacOSAgent {
    public static let version = SharedCore.version
}
#endif
