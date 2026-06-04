#if canImport(UIKit)
import Foundation
import CoreMedia
import Network
import SharedCore

/// iOS client orchestrator: connects over QUIC, sends gestures as input, and turns
/// received video frames into displayable sample buffers (F2/F3/F8).
public final class RemoteDesktopClient {
    private let transport = NWTransport()
    private let session: ClientSession
    private let decoder = VideoStreamDecoder()
    private let deviceID: UUID
    private var host = ""
    private var port: UInt16 = 7000
    private var endpoint: NWEndpoint?
    private var reconnection = ReconnectionController()

    /// Called on the transport queue with each decoded sample buffer (enqueue into the view).
    public var onSampleBuffer: ((CMSampleBuffer) -> Void)?
    /// Called with connection state changes.
    public var onState: ((TransportState) -> Void)?

    public init(deviceID: UUID = UUID()) {
        self.deviceID = deviceID
        session = ClientSession(transport: transport)
        session.onState = { [weak self] state in
            guard let self else { return }
            self.onState?(state)
            switch state {
            case .ready:  self.reconnection.reset()
            case .failed: self.scheduleReconnect()
            default:      break
            }
        }
        session.onControl = { [weak self] control in
            if case .videoFormat(let sps, let pps) = control {
                self?.decoder.setParameterSets(sps: Data(sps), pps: Data(pps))
            }
        }
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
        self.host = host
        self.port = port
        self.endpoint = nil
        reconnection.reset()
        transport.connect(host: host, port: port)
        session.sendHello(deviceID: deviceID)
    }

    /// Connects to a discovered Bonjour endpoint (no IP needed).
    public func connect(to endpoint: NWEndpoint) {
        self.endpoint = endpoint
        reconnection.reset()
        transport.connect(to: endpoint)
        session.sendHello(deviceID: deviceID)
    }

    private func scheduleReconnect() {
        guard let delay = reconnection.nextDelay() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if let endpoint = self.endpoint {
                self.transport.connect(to: endpoint)
            } else {
                self.transport.connect(host: self.host, port: self.port)
            }
        }
    }

    public func send(gesture: Gesture) { session.send(gesture: gesture) }

    public func setParameterSets(sps: Data, pps: Data) { decoder.setParameterSets(sps: sps, pps: pps) }

    public func disconnect() { transport.stop() }
}
#endif
