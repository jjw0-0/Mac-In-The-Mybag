import Foundation

#if os(macOS)
import MacOSAgent
import SharedCore

// Diagnostic: `mitm-agent probe <host> <port>` connects as a client and prints the
// connection state — used to isolate transport handshake vs network reachability.
if CommandLine.arguments.contains("probe") {
    let args = CommandLine.arguments
    let idx = args.firstIndex(of: "probe")!
    let probeHost = args.count > idx + 1 ? args[idx + 1] : "127.0.0.1"
    let probePort = args.count > idx + 2 ? (UInt16(args[idx + 2]) ?? 7000) : 7000
    let probe = NWTransport()
    probe.onStateChange = { state in
        print("probe state: \(state)")
        if state == .ready {
            probe.send(.control, ControlCodec.encode(.hello(deviceID: UUID())))
            print("probe: sent hello")
        }
    }
    probe.onReceive = { message in print("probe received on \(message.channel): \(message.payload.count) bytes") }
    setvbuf(stdout, nil, _IONBF, 0)
    print("probing \(probeHost):\(probePort) …")
    probe.connect(host: probeHost, port: probePort)
    DispatchQueue.main.asyncAfter(deadline: .now() + 6) { exit(0) }
    RunLoop.main.run()
}

let port: UInt16 = {
    if let raw = ProcessInfo.processInfo.environment["MITM_PORT"], let value = UInt16(raw) { return value }
    return 7000
}()

let agent = Agent(port: port)

// Pairing bootstrap (development aid): print connection hints and a scannable QR.
let ecdh = ECDHKeyExchange()
let hints = LocalNetwork.ipv4Addresses().map { "\($0):\(port)" }
let nonce = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
let pairing = PairingPayload(hostName: Host.current().localizedName ?? "Mac",
                             publicKey: ecdh.publicKeyData,
                             connectionHints: hints,
                             nonce: nonce)
print("Connection hints: \(hints.isEmpty ? ["<no IPv4 found>"] : hints)")
print("Pairing payload (QR contents): \(pairing.qrString())")
if let qr = TerminalQR.render(pairing.qrString()) {
    print("\nScan this QR from the iOS app (or use manual connect):\n\(qr)\n")
}

Task {
    do {
        try await agent.start()
        print("Mac-In-The-Myphone agent listening on :\(port)")
    } catch {
        FileHandle.standardError.write(Data("agent failed to start: \(error)\n".utf8))
        exit(1)
    }
}

RunLoop.main.run()
#else
print("mitm-agent runs on macOS only.")
#endif
