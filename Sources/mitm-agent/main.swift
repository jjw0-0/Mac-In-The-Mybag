import Foundation

#if os(macOS)
import MacOSAgent
import SharedCore

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
        print("Mac-In-The-Mybag agent listening on :\(port)")
    } catch {
        FileHandle.standardError.write(Data("agent failed to start: \(error)\n".utf8))
        exit(1)
    }
}

RunLoop.main.run()
#else
print("mitm-agent runs on macOS only.")
#endif
