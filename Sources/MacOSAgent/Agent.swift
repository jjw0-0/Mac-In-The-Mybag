#if os(macOS)
import Foundation
import CoreGraphics
import CoreMedia
import SharedCore

/// Wires the agent pipeline together: virtual display → capture → encode → transport,
/// and transport → input injection / control handling (F1–F8).
///
/// Note: state is touched from the capture and transport queues; synchronization here is
/// intentionally minimal for this pre-integration stage and will be hardened before
/// device testing.
public final class Agent: ScreenCapturerDelegate, @unchecked Sendable {
    private let transport = NWTransport()
    private let capturer = ScreenCapturer()
    private let displayProvider = CGVirtualDisplayProvider()
    private let injector = InputInjector()
    private let wake = WakeAssertion()
    private let thermal = ThermalMonitor()

    private var encoder: VideoEncoder?
    private var abr = AdaptiveBitrateController()
    private var replayGuard = ReplayGuard()
    private var displayHandle: DisplayHandle?
    private var bounds = CGRect.zero
    private var forceNextKeyframe = false

    private let port: UInt16

    public init(port: UInt16 = 7000) {
        self.port = port
    }

    public func start(width: Int = 1920, height: Int = 1080, fps: Int = 60) async throws {
        wake.begin()
        bounds = CGRect(x: 0, y: 0, width: width, height: height)

        transport.onReceive = { [weak self] message in self?.handle(message) }
        transport.onStateChange = { state in
            FileHandle.standardError.write(Data("transport: \(state)\n".utf8))
        }

        // Listen FIRST so the agent is reachable even if the capture pipeline isn't ready.
        try transport.listen(port: port, serviceName: "Mac-In-The-Mybag")

        // Capture pipeline — non-fatal: failures (e.g. missing Screen Recording permission)
        // are logged but do not stop the agent from accepting connections.
        do {
            let handle = try displayProvider.makeDisplay(width: width, height: height, refreshHz: Double(fps))
            displayHandle = handle

            let encoder = try VideoEncoder(width: width, height: height, codec: abr.quality.codec, fps: fps)
            encoder.onEncodedFrame = { [weak self] header, data in
                var packet = header.encoded()
                packet.append(contentsOf: data)
                self?.transport.send(.video, packet)
            }
            encoder.onParameterSets = { [weak self] sps, pps in
                self?.transport.send(.control, ControlCodec.encode(.videoFormat(sps: [UInt8](sps), pps: [UInt8](pps))))
            }
            self.encoder = encoder

            capturer.delegate = self
            try await capturer.start(displayID: handle.displayID, width: width, height: height, fps: fps)
        } catch {
            FileHandle.standardError.write(Data("capture unavailable (agent still listening): \(error)\n".utf8))
        }
    }

    public func stop() async {
        await capturer.stop()
        transport.stop()
        if let handle = displayHandle { displayProvider.release(handle) }
        wake.end()
    }

    // MARK: - ScreenCapturerDelegate

    public func screenCapturer(_ capturer: ScreenCapturer, didOutput pixelBuffer: CVPixelBuffer, pts: CMTime) {
        let force = forceNextKeyframe
        forceNextKeyframe = false
        encoder?.encode(pixelBuffer, pts: pts, forceKeyframe: force)
    }

    // MARK: - Incoming

    private func handle(_ message: FramedMessage) {
        switch message.channel {
        case .input:
            guard let command = try? InputCodec.decode(message.payload),
                  replayGuard.accept(command) else { return }
            injector.apply(command.event, within: bounds)
        case .control:
            if let control = try? ControlCodec.decode(message.payload) { handleControl(control) }
        case .video:
            break // the agent sends video, it does not receive it
        }
    }

    private func handleControl(_ message: ControlMessage) {
        switch message {
        case .hello(let deviceID):
            let token = UInt64(bitPattern: Int64(deviceID.hashValue))
            transport.send(.control, ControlCodec.encode(.helloAck(sessionToken: token)))
        case .ping(let nonce, let sentMicros):
            transport.send(.control, ControlCodec.encode(.pong(nonce: nonce, sentMicros: sentMicros)))
        case .requestKeyframe:
            forceNextKeyframe = true
        default:
            break
        }
    }
}
#endif
