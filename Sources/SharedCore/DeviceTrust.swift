import Foundation

/// A paired device the host trusts.
public struct TrustedDevice: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let publicKey: Data
    public let pairedAt: Date
    public var lastUsedAt: Date

    public init(id: UUID, name: String, publicKey: Data, pairedAt: Date, lastUsedAt: Date) {
        self.id = id
        self.name = name
        self.publicKey = publicKey
        self.pairedAt = pairedAt
        self.lastUsedAt = lastUsedAt
    }
}

/// Device-trust list with idle expiry and manual revocation (DG-3 hybrid policy:
/// indefinite trust + 14-day idle expiry + revoke).
public struct DeviceTrustStore: Sendable {
    /// Trust expires after this much inactivity (DG-3).
    public static let idleExpiry: TimeInterval = 14 * 24 * 60 * 60

    public private(set) var devices: [UUID: TrustedDevice]

    public init(devices: [UUID: TrustedDevice] = [:]) {
        self.devices = devices
    }

    public mutating func trust(_ device: TrustedDevice) {
        devices[device.id] = device
    }

    /// Records activity, resetting the idle-expiry clock.
    public mutating func touch(_ id: UUID, now: Date) {
        devices[id]?.lastUsedAt = now
    }

    public mutating func revoke(_ id: UUID) {
        devices[id] = nil
    }

    /// True if the device is present and within the idle-expiry window.
    public func isTrusted(_ id: UUID, now: Date) -> Bool {
        guard let device = devices[id] else { return false }
        return now.timeIntervalSince(device.lastUsedAt) <= Self.idleExpiry
    }
}
