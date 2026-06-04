import Foundation
import CryptoKit

/// The data carried by the pairing QR code (out-of-band channel).
///
/// Carries the host's ephemeral ECDH public key plus its fingerprint so the client can
/// verify it out-of-band (MITM resistance, D3), and connection hints for discovery
/// fallback (IP-hint, see DG-2).
public struct PairingPayload: Codable, Equatable, Sendable {
    public var version: Int
    public var hostName: String
    public var publicKey: Data
    public var connectionHints: [String]   // e.g. ["192.168.2.1:7000"]
    public var nonce: Data

    /// SHA-256 of `publicKey` (derived, not encoded — keeps the QR small).
    public var fingerprint: String { Fingerprint.sha256Hex(publicKey) }

    public init(version: Int = 1,
                hostName: String,
                publicKey: Data,
                connectionHints: [String],
                nonce: Data) {
        self.version = version
        self.hostName = hostName
        self.publicKey = publicKey
        self.connectionHints = connectionHints
        self.nonce = nonce
    }

    /// Compact, URL-safe string suitable for a QR code.
    public func qrString() -> String {
        let json = (try? JSONEncoder().encode(self)) ?? Data()
        return Base64URL.encode(json)
    }

    /// Parses a QR string. Returns nil for malformed or truncated input (UT-P5).
    public static func from(qrString string: String) -> PairingPayload? {
        guard let data = Base64URL.decode(string) else { return nil }
        return try? JSONDecoder().decode(PairingPayload.self, from: data)
    }
}

/// X25519 (Curve25519) ECDH key agreement.
public struct ECDHKeyExchange {
    private let privateKey: Curve25519.KeyAgreement.PrivateKey

    public init() {
        privateKey = Curve25519.KeyAgreement.PrivateKey()
    }

    public var publicKeyData: Data { privateKey.publicKey.rawRepresentation }

    /// Derives a 256-bit symmetric key shared with the peer (HKDF-SHA256).
    public func deriveSharedKey(peerPublicKey: Data,
                                salt: Data = Data(),
                                info: Data = Data("Mac-In-The-Mybag/v1".utf8)) throws -> SymmetricKey {
        let peer = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: peer)
        return secret.hkdfDerivedSymmetricKey(using: SHA256.self,
                                              salt: salt,
                                              sharedInfo: info,
                                              outputByteCount: 32)
    }
}

public enum Fingerprint {
    /// Lowercase hex SHA-256 of the input (used for out-of-band key verification).
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// Length-independent? No — length is not secret. Compares contents in constant time
/// once lengths match, to avoid leaking secret bytes via timing (UT-P4).
public func constantTimeEquals(_ a: Data, _ b: Data) -> Bool {
    guard a.count == b.count else { return false }
    var diff: UInt8 = 0
    for (x, y) in zip(a, b) { diff |= x ^ y }
    return diff == 0
}

enum Base64URL {
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    static func decode(_ string: String) -> Data? {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        return Data(base64Encoded: s)
    }
}
