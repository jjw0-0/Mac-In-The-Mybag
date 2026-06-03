import Foundation

/// Touch gestures from the client, before translation to input events (G3, DG-6).
public enum Gesture: Equatable, Sendable {
    case panMoved(dx: Double, dy: Double)          // 1-finger drag → relative cursor move
    case tap                                        // → left click
    case twoFingerTap                               // → right click
    case twoFingerScroll(dx: Double, dy: Double)    // → scroll
    case longPressDragBegan                         // → left button down (begin drag)
    case longPressDragEnded                         // → left button up (end drag)
}

/// Maps the trackpad-style gesture set (DG-6) to one or more `InputEvent`s.
public enum GestureInterpreter {
    public static func translate(_ gesture: Gesture) -> [InputEvent] {
        switch gesture {
        case .panMoved(let dx, let dy):
            return [.pointerMove(.relative(dx: dx, dy: dy))]
        case .tap:
            return [.mouseButton(.left, .down), .mouseButton(.left, .up)]
        case .twoFingerTap:
            return [.mouseButton(.right, .down), .mouseButton(.right, .up)]
        case .twoFingerScroll(let dx, let dy):
            return [.scroll(Scroll(dx: dx, dy: dy))]
        case .longPressDragBegan:
            return [.mouseButton(.left, .down)]
        case .longPressDragEnded:
            return [.mouseButton(.left, .up)]
        }
    }
}
