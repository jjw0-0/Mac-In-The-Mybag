import Foundation

/// iOSClient — 모듈 자리표시(플랫폼 무관 부분).
/// macOS 호스트에서 `swift build` 시 아래 `#if os(iOS)` 블록은 비어 빌드를 막지 않는다.
public enum IOSClientModule {
    public static let platformGuarded = true
}

#if os(iOS)
import SharedCore

/// iOSClient — 화면 수신/디코딩/렌더링 · 제스처(G3 트랙패드 기본, DG-6) ·
/// 페어링 UI(D3 QR+ECDH) · L2 계측 하니스(F-L2).
public enum IOSClient {
    public static let version = SharedCore.version
}
#endif
