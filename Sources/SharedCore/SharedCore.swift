import Foundation

/// SharedCore — Mac-to-Phone 양 플랫폼 공유 코어.
///
/// 프로토콜 정의 · 입력 인코딩/디코딩 · 연결 상태 머신 · 좌표 변환 · 암호 추상화를 담는다.
/// 플랫폼 프레임워크(ScreenCaptureKit / UIKit 등)에 의존하지 않는 **순수 로직만** 둔다(테스트 용이).
public enum SharedCore {
    /// 빌드 식별용 버전.
    public static let version = "0.0.1"
}
