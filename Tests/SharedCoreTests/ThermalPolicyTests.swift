import XCTest
@testable import SharedCore

/// Thermal pressure → encode action (DG-1 / F14).
final class ThermalPolicyTests: XCTestCase {
    func testMapping() {
        XCTAssertEqual(ThermalPolicy.action(for: .nominal), .full)
        XCTAssertEqual(ThermalPolicy.action(for: .fair), .full)
        XCTAssertEqual(ThermalPolicy.action(for: .serious), .powerSave)
        XCTAssertEqual(ThermalPolicy.action(for: .critical), .suspend)
    }
}
