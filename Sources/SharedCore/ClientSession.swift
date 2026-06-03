import Foundation

/// Cross-platform client session logic: stamps and sends input, sends control, and
/// surfaces incoming video frames. Platform-specific decoding/rendering subscribes to
/// `onVideoFrame`. (Used by the iOS client; transport is injected for testability.)
public final class ClientSession: @unchecked Sendable {
    private let transport: Transport
    private var sequencer = InputSequencer()

    /// Called with each received video frame (header + compressed payload).
    public var onVideoFrame: ((VideoFrameHeader, [UInt8]) -> Void)?
    /// Called with received control messages (e.g. helloAck, pong).
    public var onControl: ((ControlMessage) -> Void)?
    public var onState: ((TransportState) -> Void)?

    public init(transport: Transport) {
        self.transport = transport
        transport.onReceive = { [weak self] message in self?.handle(message) }
        transport.onStateChange = { [weak self] state in self?.onState?(state) }
    }

    /// Stamps an input event with the next sequence number and sends it.
    public func send(_ event: InputEvent) {
        transport.send(.input, InputCodec.encode(sequencer.stamp(event)))
    }

    /// Translates and sends a gesture (may be more than one input event).
    public func send(gesture: Gesture) {
        for event in GestureInterpreter.translate(gesture) { send(event) }
    }

    public func sendHello(deviceID: UUID) {
        transport.send(.control, ControlCodec.encode(.hello(deviceID: deviceID)))
    }

    public func requestKeyframe() {
        transport.send(.control, ControlCodec.encode(.requestKeyframe))
    }

    private func handle(_ message: FramedMessage) {
        switch message.channel {
        case .video:
            if let (header, payload) = try? VideoFrameHeader.decode(message.payload) {
                onVideoFrame?(header, payload)
            }
        case .control:
            if let control = try? ControlCodec.decode(message.payload) {
                onControl?(control)
            }
        case .input:
            break
        }
    }
}
