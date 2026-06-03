#if canImport(UIKit)
import UIKit
import SwiftUI
import AVFoundation
import CoreMedia

/// A UIView backed by `AVSampleBufferDisplayLayer` that renders decoded video frames (F2).
public final class SampleBufferView: UIView {
    public override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }

    public var displayLayer: AVSampleBufferDisplayLayer {
        // swiftlint:disable:next force_cast
        layer as! AVSampleBufferDisplayLayer
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer) {
        if displayLayer.status == .failed { displayLayer.flush() }
        displayLayer.enqueue(sampleBuffer)
    }
}

/// SwiftUI wrapper that hands back the underlying `SampleBufferView` for frame enqueuing.
public struct RemoteScreenView: UIViewRepresentable {
    private let onMake: (SampleBufferView) -> Void

    public init(onMake: @escaping (SampleBufferView) -> Void) {
        self.onMake = onMake
    }

    public func makeUIView(context: Context) -> SampleBufferView {
        let view = SampleBufferView()
        view.backgroundColor = .black
        onMake(view)
        return view
    }

    public func updateUIView(_ uiView: SampleBufferView, context: Context) {}
}
#endif
