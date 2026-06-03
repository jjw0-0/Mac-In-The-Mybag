#if os(macOS)
import XCTest
@testable import MacOSAgent

/// Construction wiring only — a live `start()` needs TCC permissions and a client,
/// so it is exercised by manual/integration testing.
final class AgentTests: XCTestCase {
    func testAgentInstantiates() {
        let agent = Agent(port: 7000)
        XCTAssertNotNil(agent)
    }
}
#endif
