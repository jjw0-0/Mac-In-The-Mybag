import Foundation

/// Encoder power mode chosen in response to thermal pressure (DG-1, F14).
public enum EncodePower: Equatable, Sendable {
    case full        // normal capture/encode
    case powerSave   // reduced resolution / fps to shed heat
    case suspend     // stop capturing and warn — safety beats continuity
}

/// Pure mapping from the OS thermal pressure level to an encode action.
///
/// DG-1 is safety-first: as the device heats up we step down to a power-save encode and,
/// at the top of the scale, suspend rather than risk the battery.
public enum ThermalPolicy {
    public static func action(for state: ProcessInfo.ThermalState) -> EncodePower {
        switch state {
        case .nominal, .fair: return .full
        case .serious:        return .powerSave
        case .critical:       return .suspend
        @unknown default:     return .powerSave
        }
    }
}
