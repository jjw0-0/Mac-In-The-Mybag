import Foundation

/// A pointer movement — an absolute position (pt, see DG-10) or a relative delta.
public enum PointerMove: Equatable, Sendable {
    case absolute(LogicalPoint)
    case relative(dx: Double, dy: Double)
}

public enum MouseButton: UInt8, Equatable, Sendable {
    case left = 0, right = 1, middle = 2
}

public enum ButtonAction: UInt8, Equatable, Sendable {
    case down = 0, up = 1
}

/// A scroll delta (pixel-precise); `isMomentum` marks inertial scroll frames.
public struct Scroll: Equatable, Sendable {
    public var dx: Double
    public var dy: Double
    public var isMomentum: Bool
    public init(dx: Double, dy: Double, isMomentum: Bool = false) {
        self.dx = dx
        self.dy = dy
        self.isMomentum = isMomentum
    }
}

/// Keyboard modifier flags.
public struct Modifiers: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let shift    = Modifiers(rawValue: 1 << 0)
    public static let control  = Modifiers(rawValue: 1 << 1)
    public static let option   = Modifiers(rawValue: 1 << 2)
    public static let command  = Modifiers(rawValue: 1 << 3)
    public static let capsLock = Modifiers(rawValue: 1 << 4)
    public static let function = Modifiers(rawValue: 1 << 5)
}

public struct KeyEvent: Equatable, Sendable {
    public var keyCode: UInt16
    public var action: ButtonAction
    public var modifiers: Modifiers
    public init(keyCode: UInt16, action: ButtonAction, modifiers: Modifiers = []) {
        self.keyCode = keyCode
        self.action = action
        self.modifiers = modifiers
    }
}

/// A single input command sent from the client to the host.
public enum InputEvent: Equatable, Sendable {
    case pointerMove(PointerMove)
    case mouseButton(MouseButton, ButtonAction)
    case scroll(Scroll)
    case key(KeyEvent)
}

/// An input command tagged with a monotonically increasing sequence number,
/// used for ordering and replay defense (see `ReplayGuard`, UT-I6 / SEC-7).
public struct SequencedInput: Equatable, Sendable {
    public var sequence: UInt64
    public var event: InputEvent
    public init(sequence: UInt64, event: InputEvent) {
        self.sequence = sequence
        self.event = event
    }
}
