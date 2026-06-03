#if canImport(UIKit)
import Foundation
import CoreMedia
import SharedCore

/// iOS client orchestrator: connects over QUIC, sends gestures as input, and turns
/// received video frames into displayable sample buffers (F2/F3/F8).
public final class RemoteDesktopClient {
    private let transport = NWTransport()
    private let session: ClientSession
    private let decoder = VideoStreamDecoder()
    private let deviceID: UUID

    /// Called on the transport queue with each decoded sample buffer (enqueue into the view).
    public var onSampleBuffer: ((CMSampleBuffer) -> Void)?
    /// Called with connection state changes.
    public var onState: ((TransportState) -> Void)?

    public init(deviceID: UUID = UUID()) {
        self.deviceID = deviceID
        session = ClientSession(transport: transport)
        session.onState = { [weak self] state in self?.onState?(state) }
        session.onVideoFrame = { [weak self] header, payload in
            guard let self else { return }
            if let sampleBuffer = self.decoder.sampleBuffer(forFrame: Data(payload),
                                                            ptsMicros: header.ptsMicros,
                                                            isKeyframe: header.isKeyframe) {
                self.onSampleBuffer?(sampleBuffer)
            } else if header.isKeyframe {
                // Not yet decodable (parameter sets pending) — ask the agent for a fresh keyframe.
                self.session.requestKeyframe()
            }
        }
    }

    public func connect(host: String, port: UInt16 = 7000) {
        transport.connect(host: host, port: port)
        session.sendHello(deviceID: deviceID)
    }

    public func send(gesture: Gesture) { session.send(gesture: gesture) }

    public func setParameterSets(sps: Data, pps: Data) { decoder.setParameterSets(sps: sps, pps: pps) }

    public func disconnect() { transport.stop() }
}
#endif
