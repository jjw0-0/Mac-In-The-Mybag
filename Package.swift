// swift-tools-version: 5.9
import PackageDescription

// H2: 분리 타깃 + SharedCore (단일 Swift Package, 다중 타깃)
// 아키텍처 개요는 루트 README.md 참조.
let package = Package(
    name: "MacInTheMybag",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "SharedCore", targets: ["SharedCore"]),
        .library(name: "MacOSAgent", targets: ["MacOSAgent"]),
        .library(name: "IOSClient", targets: ["IOSClient"]),
    ],
    targets: [
        // 플랫폼 무관 순수 로직 — UT 집중
        .target(name: "SharedCore"),
        // macOS 전용 (화면 캡처/CGEvent/DisplayProvider) — 내부 #if os(macOS) 가드
        .target(name: "MacOSAgent", dependencies: ["SharedCore"]),
        // iOS 전용 (렌더링/제스처/페어링/L2) — 내부 #if os(iOS) 가드
        .target(name: "IOSClient", dependencies: ["SharedCore"]),
        .testTarget(name: "SharedCoreTests", dependencies: ["SharedCore"]),
    ]
)
