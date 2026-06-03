#if os(macOS)
import Foundation
import CoreGraphics
import SharedCore

/// Applies decoded `InputEvent`s to the host using Core Graphics events (C1, F3/F4).
/// Requires Accessibility permission at runtime (see `Permissions`).
public final class InputInjector {
    private let source: CGEventSource?
    private var position: CGPoint
    private var leftDown = false
    private var rightDown = false

    public init(initialPosition: CGPoint = .zero) {
        source = CGEventSource(stateID: .hidSystemState)
        position = initialPosition
    }

    /// Applies one event. `bounds` is the target display's pixel/point rect, used to
    /// clamp the cursor and to interpret absolute (pt) coordinates.
    public func apply(_ event: InputEvent, within bounds: CGRect) {
        switch event {
        case .pointerMove(let move):
            switch move {
            case .absolute(let p):           position = CGPoint(x: p.x, y: p.y)
            case .relative(let dx, let dy):  position = CGPoint(x: position.x + dx, y: position.y + dy)
            }
            position = Self.clamp(position, to: bounds)
            postMove()
        case .mouseButton(let button, let action):
            postButton(button, action)
        case .scroll(let scroll):
            postScroll(scroll)
        case .key(let key):
            postKey(key)
        }
    }

    // MARK: - Posting

    private func postMove() {
        let type: CGEventType = leftDown ? .leftMouseDragged : (rightDown ? .rightMouseDragged : .mouseMoved)
        let button: CGMouseButton = rightDown ? .right : .left
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: position, mouseButton: button)?
            .post(tap: .cghidEventTap)
    }

    private func postButton(_ button: MouseButton, _ action: ButtonAction) {
        let type: CGEventType
        let cgButton: CGMouseButton
        switch (button, action) {
        case (.left, .down):   type = .leftMouseDown;  cgButton = .left;   leftDown = true
        case (.left, .up):     type = .leftMouseUp;    cgButton = .left;   leftDown = false
        case (.right, .down):  type = .rightMouseDown; cgButton = .right;  rightDown = true
        case (.right, .up):    type = .rightMouseUp;   cgButton = .right;  rightDown = false
        case (.middle, .down): type = .otherMouseDown; cgButton = .center
        case (.middle, .up):   type = .otherMouseUp;   cgButton = .center
        }
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: position, mouseButton: cgButton)?
            .post(tap: .cghidEventTap)
    }

    private func postScroll(_ scroll: Scroll) {
        CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                wheel1: Self.clampedInt32(scroll.dy),
                wheel2: Self.clampedInt32(scroll.dx),
                wheel3: 0)?
            .post(tap: .cghidEventTap)
    }

    private func postKey(_ key: KeyEvent) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: key.keyCode, keyDown: key.action == .down)
        event?.flags = Self.cgFlags(key.modifiers)
        event?.post(tap: .cghidEventTap)
    }

    // MARK: - Pure helpers (testable)

    static func cgFlags(_ modifiers: Modifiers) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.shift)    { flags.insert(.maskShift) }
        if modifiers.contains(.control)  { flags.insert(.maskControl) }
        if modifiers.contains(.option)   { flags.insert(.maskAlternate) }
        if modifiers.contains(.command)  { flags.insert(.maskCommand) }
        if modifiers.contains(.capsLock) { flags.insert(.maskAlphaShift) }
        if modifiers.contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    static func clamp(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else { return point }
        return CGPoint(x: Swift.min(Swift.max(point.x, bounds.minX), bounds.maxX),
                       y: Swift.min(Swift.max(point.y, bounds.minY), bounds.maxY))
    }

    static func clampedInt32(_ value: Double) -> Int32 {
        guard !value.isNaN else { return 0 }
        let rounded = value.rounded()
        if rounded >= Double(Int32.max) { return Int32.max }
        if rounded <= Double(Int32.min) { return Int32.min }
        return Int32(rounded)
    }
}
#endif
