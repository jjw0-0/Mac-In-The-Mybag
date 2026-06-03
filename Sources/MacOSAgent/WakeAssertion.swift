#if os(macOS)
import Foundation
import IOKit.pwr_mgt

/// Holds a power-management assertion that prevents idle system sleep while a session
/// is active (F7). Note: this suppresses *idle* sleep only; keeping a capture surface
/// alive with the lid closed is handled separately by `CGVirtualDisplayProvider`.
public final class WakeAssertion {
    private var assertionID: IOPMAssertionID = 0
    private var active = false

    public init() {}

    @discardableResult
    public func begin(reason: String = "Mac-In-The-Mybag active session") -> Bool {
        guard !active else { return true }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        guard result == kIOReturnSuccess else { return false }
        assertionID = id
        active = true
        return true
    }

    public func end() {
        guard active else { return }
        IOPMAssertionRelease(assertionID)
        active = false
    }

    deinit { end() }
}
#endif
