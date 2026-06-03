#if os(macOS)
import Foundation
import SharedCore

/// Watches the system thermal state and maps it to an encode action via `ThermalPolicy`
/// (DG-1 / F14).
public final class ThermalMonitor {
    public init() {}

    /// The encode action recommended for the current thermal state.
    public var currentAction: EncodePower {
        ThermalPolicy.action(for: ProcessInfo.processInfo.thermalState)
    }

    /// Observes thermal-state changes; `handler` is called with the new action.
    /// Returns the observer token; remove it with `NotificationCenter.default.removeObserver`.
    public func observe(_ handler: @escaping (EncodePower) -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            handler(ThermalPolicy.action(for: ProcessInfo.processInfo.thermalState))
        }
    }
}
#endif
