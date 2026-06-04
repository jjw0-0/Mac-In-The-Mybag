#if os(macOS)
import Foundation
import SharedCore
import CVirtualDisplay

/// `DisplayProvider` backed by `CGVirtualDisplay` (private CoreGraphics interface).
///
/// Provides a headless capture surface so the agent can keep producing frames when
/// no physical display is attached — the production form of G-Sleep path (iii),
/// validated by the kill-gate PoC. The private interface is resolved at runtime;
/// when it is unavailable, `makeDisplay` throws `.unsupported`.
public final class CGVirtualDisplayProvider: DisplayProvider {

    /// Display name reported to the system.
    private let name: String

    public init(name: String = "Mac-In-The-Myphone") {
        self.name = name
    }

    public func makeDisplay(width: Int, height: Int, refreshHz: Double) throws -> DisplayHandle {
        precondition(width > 0 && height > 0, "display dimensions must be positive")
        let displayID = name.withCString {
            CVirtualDisplayCreate($0, UInt(width), UInt(height), refreshHz)
        }
        guard displayID != 0 else { throw DisplayProviderError.creationFailed }
        return DisplayHandle(displayID: displayID, width: width, height: height)
    }

    public func release(_ handle: DisplayHandle) {
        _ = CVirtualDisplayRelease(handle.displayID)
    }

    /// Releases every virtual display created through this bridge.
    public func releaseAll() {
        CVirtualDisplayReleaseAll()
    }
}
#endif
