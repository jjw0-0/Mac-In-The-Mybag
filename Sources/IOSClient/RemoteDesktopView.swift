#if canImport(UIKit)
import SwiftUI
import SharedCore

/// Bridges `TrackpadView` into SwiftUI.
public struct GestureOverlay: UIViewRepresentable {
    private let onGesture: (SharedCore.Gesture) -> Void
    public init(onGesture: @escaping (SharedCore.Gesture) -> Void) { self.onGesture = onGesture }

    public func makeUIView(context: Context) -> TrackpadView {
        let view = TrackpadView()
        view.onGesture = onGesture
        view.backgroundColor = .clear
        return view
    }
    public func updateUIView(_ uiView: TrackpadView, context: Context) {}
}

/// Observable connection state + client lifecycle for `RemoteDesktopView`.
@MainActor
public final class RemoteDesktopModel: ObservableObject {
    @Published public var isConnected = false
    public private(set) var client: RemoteDesktopClient?
    private weak var screenView: SampleBufferView?

    public init() {}

    public func attach(_ view: SampleBufferView) { screenView = view }

    /// Parses a scanned pairing QR and connects to the first usable connection hint.
    public func handleScannedCode(_ code: String) {
        guard let payload = PairingPayload.from(qrString: code),
              let hint = payload.connectionHints.first else { return }
        let pieces = hint.split(separator: ":")
        let host = String(pieces.first ?? "")
        let port = pieces.count > 1 ? (UInt16(pieces[1]) ?? 7000) : 7000
        connectManually(host: host, port: port)
    }

    /// Connects directly to a host/port (manual entry; bypasses QR).
    public func connectManually(host: String, port: UInt16) {
        guard !host.isEmpty else { return }
        let client = makeClient()
        client.connect(host: host, port: port)
        self.client = client
    }

    private func makeClient() -> RemoteDesktopClient {
        let client = RemoteDesktopClient()
        client.onSampleBuffer = { [weak self] sampleBuffer in
            DispatchQueue.main.async { self?.screenView?.enqueue(sampleBuffer) }
        }
        client.onState = { [weak self] state in
            DispatchQueue.main.async { self?.isConnected = (state == .ready) }
        }
        return client
    }
}

/// The app's main screen: scan a pairing QR, then render the remote desktop with a
/// trackpad overlay. Embed this in an iOS app target.
public struct RemoteDesktopView: View {
    @StateObject private var model = RemoteDesktopModel()
    @State private var host = ""
    @State private var portText = "7000"

    public init() {}

    public var body: some View {
        ZStack {
            if model.isConnected {
                RemoteScreenView { view in model.attach(view) }
                    .ignoresSafeArea()
                GestureOverlay { gesture in model.client?.send(gesture: gesture) }
                    .ignoresSafeArea()
            } else {
                QRScannerView { code in model.handleScannedCode(code) }
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    Spacer()
                    Text("Scan the pairing QR shown on your Mac")
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                    HStack(spacing: 8) {
                        TextField("host", text: $host)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        TextField("port", text: $portText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 72)
                        Button("Connect") {
                            model.connectManually(host: host, port: UInt16(portText) ?? 7000)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}
#endif
