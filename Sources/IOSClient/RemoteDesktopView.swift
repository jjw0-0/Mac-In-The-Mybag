#if canImport(UIKit)
import SwiftUI
import Network
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
    @Published public var status: String = ""
    public private(set) var client: RemoteDesktopClient?
    private weak var screenView: SampleBufferView?
    private let discovery = Discovery()
    @Published public var devices: [Discovery.Device] = []

    public init() {}

    public func attach(_ view: SampleBufferView) { screenView = view }

    /// Starts Bonjour discovery. This also triggers the iOS Local Network permission prompt.
    public func startDiscovery() {
        discovery.onDevices = { [weak self] devices in
            DispatchQueue.main.async { self?.devices = devices }
        }
        discovery.start()
    }

    /// Connects to a discovered agent (no IP typing needed).
    public func connect(to device: Discovery.Device) {
        status = "Connecting to \(device.name)…"
        let client = makeClient()
        client.connect(to: device.endpoint)
        self.client = client
    }

    /// Parses a scanned pairing QR and connects to the first usable connection hint.
    public func handleScannedCode(_ code: String) {
        guard let payload = PairingPayload.from(qrString: code),
              let hint = payload.connectionHints.first else { return }
        let pieces = hint.split(separator: ":")
        let host = String(pieces.first ?? "")
        let port = pieces.count > 1 ? (UInt16(pieces[1]) ?? 7000) : 7000
        connectManually(host: host, port: port)
    }

    /// Connects directly to a host/port (manual entry; bypasses QR). Tolerates an
    /// "ip:port" string pasted into the host field.
    public func connectManually(host rawHost: String, port: UInt16) {
        var host = rawHost.trimmingCharacters(in: .whitespaces)
        var resolvedPort = port
        if let colon = host.lastIndex(of: ":"),
           let parsed = UInt16(host[host.index(after: colon)...]) {
            resolvedPort = parsed
            host = String(host[..<colon])
        }
        guard !host.isEmpty else { status = "Enter a host (e.g. 192.168.0.12)"; return }
        status = "Connecting to \(host):\(resolvedPort)…"
        let client = makeClient()
        client.connect(host: host, port: resolvedPort)
        self.client = client
    }

    private func makeClient() -> RemoteDesktopClient {
        let client = RemoteDesktopClient()
        client.onSampleBuffer = { [weak self] sampleBuffer in
            DispatchQueue.main.async { self?.screenView?.enqueue(sampleBuffer) }
        }
        client.onState = { [weak self] state in
            DispatchQueue.main.async {
                self?.isConnected = (state == .ready)
                switch state {
                case .ready:     self?.status = "Connected"
                case .failed:    self?.status = "Connection failed — check IP / Wi-Fi / agent"
                case .cancelled: self?.status = "Disconnected"
                case .setup:     self?.status = "Connecting…"
                }
            }
        }
        return client
    }
}

/// The app's main screen. Disconnected → a clean device picker (tap a Mac found on your
/// network; manual entry lives in a sheet). Connected → the remote screen with a trackpad.
public struct RemoteDesktopView: View {
    @StateObject private var model = RemoteDesktopModel()
    @State private var showManual = false
    @State private var host = ""
    @State private var portText = "7000"

    public init() {}

    public var body: some View {
        Group {
            if model.isConnected {
                remoteScreen
            } else {
                connectScreen
            }
        }
    }

    // MARK: - Connected

    private var remoteScreen: some View {
        ZStack {
            RemoteScreenView { view in model.attach(view) }
                .ignoresSafeArea()
            GestureOverlay { gesture in model.client?.send(gesture: gesture) }
                .ignoresSafeArea()
        }
    }

    // MARK: - Connect (device picker)

    private var connectScreen: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.06, blue: 0.13),
                                    Color(red: 0.10, green: 0.07, blue: 0.22)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                branding.padding(.bottom, 40)
                deviceList.padding(.horizontal, 24)
                Spacer()
                manualButton.padding(.bottom, 24)
            }
        }
        .onAppear { model.startDiscovery() }
        .sheet(isPresented: $showManual) { manualSheet }
    }

    private var branding: some View {
        VStack(spacing: 12) {
            Image(systemName: "macbook.and.iphone")
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(.white)
            Text("Mac-In-The-Myphone")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("Your Mac, in your pocket")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    @ViewBuilder private var deviceList: some View {
        if model.devices.isEmpty {
            VStack(spacing: 14) {
                ProgressView().tint(.white)
                Text("Searching for your Mac…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                statusText
            }
        } else {
            VStack(spacing: 12) {
                ForEach(model.devices) { device in
                    Button { model.connect(to: device) } label: { deviceRow(device.name) }
                        .buttonStyle(.plain)
                }
                statusText.padding(.top, 4)
            }
        }
    }

    private func deviceRow(_ name: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "desktopcomputer")
                .font(.title3).foregroundStyle(.white).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.semibold)).foregroundStyle(.white)
                Text("Tap to connect").font(.caption).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.4))
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
    }

    @ViewBuilder private var statusText: some View {
        if !model.status.isEmpty {
            Text(model.status)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var manualButton: some View {
        Button { showManual = true } label: {
            Label("Connect manually", systemImage: "keyboard")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var manualSheet: some View {
        NavigationStack {
            Form {
                Section("Mac address") {
                    TextField("Host (e.g. 192.168.0.12)", text: $host)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Port", text: $portText)
                        .keyboardType(.numberPad)
                }
                Section {
                    Button("Connect") {
                        model.connectManually(host: host, port: UInt16(portText) ?? 7000)
                        showManual = false
                    }
                    .disabled(host.isEmpty)
                }
            }
            .navigationTitle("Manual connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showManual = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
#endif
