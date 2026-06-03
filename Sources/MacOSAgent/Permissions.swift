#if os(macOS)
import Foundation
import CoreGraphics
import ApplicationServices

/// Reports and requests the TCC permissions the agent needs (F11): Screen Recording
/// (to capture) and Accessibility (to post input events).
public enum Permissions {

    public static var hasScreenRecording: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Prompts for Screen Recording access. Returns the (possibly still-pending) result.
    @discardableResult
    public static func requestScreenRecording() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    public static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    public struct Status: Equatable, Sendable {
        public let screenRecording: Bool
        public let accessibility: Bool
        public var allGranted: Bool { screenRecording && accessibility }
    }

    public static var status: Status {
        Status(screenRecording: hasScreenRecording, accessibility: hasAccessibility)
    }
}
#endif
