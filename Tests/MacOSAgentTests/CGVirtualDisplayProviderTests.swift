#if os(macOS)
import XCTest
import SharedCore
@testable import MacOSAgent

/// Wiring/conformance checks for `CGVirtualDisplayProvider`.
///
/// Note: actually creating a virtual display requires a window server and is covered
/// by manual/integration testing, not unit tests — these checks avoid creating one.
final class CGVirtualDisplayProviderTests: XCTestCase {

    func testConformsToDisplayProvider() {
        let provider: DisplayProvider = CGVirtualDisplayProvider()
        XCTAssertNotNil(provider)
    }

    func testReleasingUnknownHandleIsSafe() {
        let provider = CGVirtualDisplayProvider()
        // Releasing a handle that was never created must be a no-op (no crash).
        provider.release(DisplayHandle(displayID: 0, width: 0, height: 0))
    }
}
#endif
