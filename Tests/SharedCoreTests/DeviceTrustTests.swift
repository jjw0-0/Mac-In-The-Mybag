import XCTest
@testable import SharedCore

/// Device-trust idle expiry + revocation — DG-3, IT-H4.
final class DeviceTrustTests: XCTestCase {

    private let epoch = Date(timeIntervalSince1970: 1_000_000)

    private func device(_ id: UUID, lastUsed: Date) -> TrustedDevice {
        TrustedDevice(id: id, name: "iPhone", publicKey: Data([0xAB]), pairedAt: epoch, lastUsedAt: lastUsed)
    }

    func testTrustedWithinWindow() {
        var store = DeviceTrustStore()
        let id = UUID()
        store.trust(device(id, lastUsed: epoch))
        XCTAssertTrue(store.isTrusted(id, now: epoch))
    }

    func testExpiresAfterIdle() {
        var store = DeviceTrustStore()
        let id = UUID()
        store.trust(device(id, lastUsed: epoch))
        let after15Days = epoch.addingTimeInterval(15 * 24 * 60 * 60)
        XCTAssertFalse(store.isTrusted(id, now: after15Days))
    }

    func testTouchResetsIdleClock() {
        var store = DeviceTrustStore()
        let id = UUID()
        store.trust(device(id, lastUsed: epoch))
        let after10 = epoch.addingTimeInterval(10 * 24 * 60 * 60)
        store.touch(id, now: after10)
        let after10plus13 = after10.addingTimeInterval(13 * 24 * 60 * 60)
        XCTAssertTrue(store.isTrusted(id, now: after10plus13))
    }

    func testRevokeRemovesDevice() {
        var store = DeviceTrustStore()
        let id = UUID()
        store.trust(device(id, lastUsed: epoch))
        store.revoke(id)
        XCTAssertFalse(store.isTrusted(id, now: epoch))
        XCTAssertNil(store.devices[id])
    }

    func testUnknownDeviceNotTrusted() {
        XCTAssertFalse(DeviceTrustStore().isTrusted(UUID(), now: epoch))
    }
}
