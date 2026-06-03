#if os(macOS)
import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo

/// Receives captured frames from `ScreenCapturer`.
public protocol ScreenCapturerDelegate: AnyObject {
    func screenCapturer(_ capturer: ScreenCapturer, didOutput pixelBuffer: CVPixelBuffer, pts: CMTime)
}

/// Captures a display via ScreenCaptureKit and delivers BGRA pixel buffers (B1, F1).
/// Pairs with `CGVirtualDisplayProvider` to capture a headless virtual display.
public final class ScreenCapturer: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    public weak var delegate: ScreenCapturerDelegate?

    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "mitm.capture", qos: .userInteractive)

    public enum CaptureError: Error { case displayNotFound }

    public override init() { super.init() }

    /// Starts capturing the given display at the requested size and frame rate.
    public func start(displayID: CGDirectDisplayID, width: Int, height: Int, fps: Int) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw CaptureError.displayNotFound
        }

        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(1, fps)))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 5
        config.showsCursor = true

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    public func stop() async {
        try? await stream?.stopCapture()
        stream = nil
    }

    // MARK: - SCStreamOutput

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        delegate?.screenCapturer(self, didOutput: pixelBuffer, pts: pts)
    }

    // MARK: - SCStreamDelegate

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        self.stream = nil
    }
}
#endif
