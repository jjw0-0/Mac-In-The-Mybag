import XCTest
import CryptoKit
@testable import SharedCore

/// QR + ECDH pairing primitives — UT-P1 / UT-P4 / UT-P5, D3.
final class PairingTests: XCTestCase {

    private func keyBytes(_ key: SymmetricKey) -> Data { key.withUnsafeBytes { Data($0) } }

    func testECDHProducesMatchingSharedKey() throws {
        let alice = ECDHKeyExchange()
        let bob = ECDHKeyExchange()
        let aKey = try alice.deriveSharedKey(peerPublicKey: bob.publicKeyData)
        let bKey = try bob.deriveSharedKey(peerPublicKey: alice.publicKeyData)
        XCTAssertEqual(keyBytes(aKey), keyBytes(bKey))
        XCTAssertEqual(keyBytes(aKey).count, 32)
    }

    func testECDHRejectsInvalidPeerKey() {
        let alice = ECDHKeyExchange()
        XCTAssertThrowsError(try alice.deriveSharedKey(peerPublicKey: Data([1, 2, 3])))
    }

    func testQRPayloadRoundtrip() {
        let payload = PairingPayload(hostName: "Kevin's MacBook",
                                     publicKey: Data((0..<32).map { UInt8($0) }),
                                     connectionHints: ["192.168.2.1:7000", "10.0.0.5:7000"],
                                     nonce: Data(repeating: 7, count: 16))
        let parsed = PairingPayload.from(qrString: payload.qrString())
        XCTAssertEqual(parsed, payload)
        XCTAssertEqual(parsed?.fingerprint, Fingerprint.sha256Hex(payload.publicKey))
    }

    func testQRMalformedReturnsNil() {
        XCTAssertNil(PairingPayload.from(qrString: "!!! not base64 !!!"))
        XCTAssertNil(PairingPayload.from(qrString: ""))
    }

    func testFingerprintIsDeterministic() {
        let data = Data("hello".utf8)
        XCTAssertEqual(Fingerprint.sha256Hex(data), Fingerprint.sha256Hex(data))
        XCTAssertNotEqual(Fingerprint.sha256Hex(data), Fingerprint.sha256Hex(Data("world".utf8)))
        XCTAssertEqual(Fingerprint.sha256Hex(data).count, 64)
    }

    func testConstantTimeEquals() {
        XCTAssertTrue(constantTimeEquals(Data([1, 2, 3]), Data([1, 2, 3])))
        XCTAssertFalse(constantTimeEquals(Data([1, 2, 3]), Data([1, 2, 4])))
        XCTAssertFalse(constantTimeEquals(Data([1, 2, 3]), Data([1, 2])))
    }
}
