#if canImport(UIKit)
import UIKit
import SharedCore

/// Captures trackpad-style touch gestures and reports them as `Gesture`s (G3, DG-6).
public final class TrackpadView: UIView {
    public var onGesture: ((Gesture) -> Void)?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        installRecognizers()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        installRecognizers()
    }

    private func installRecognizers() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.maximumNumberOfTouches = 2
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap))
        twoFingerTap.numberOfTouchesRequired = 2
        addGestureRecognizer(twoFingerTap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        addGestureRecognizer(longPress)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self)
        recognizer.setTranslation(.zero, in: self)
        if recognizer.numberOfTouches >= 2 {
            onGesture?(.twoFingerScroll(dx: Double(translation.x), dy: Double(translation.y)))
        } else {
            onGesture?(.panMoved(dx: Double(translation.x), dy: Double(translation.y)))
        }
    }

    @objc private func handleTap() { onGesture?(.tap) }

    @objc private func handleTwoFingerTap() { onGesture?(.twoFingerTap) }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:            onGesture?(.longPressDragBegan)
        case .ended, .cancelled: onGesture?(.longPressDragEnded)
        default:                break
        }
    }
}
#endif
