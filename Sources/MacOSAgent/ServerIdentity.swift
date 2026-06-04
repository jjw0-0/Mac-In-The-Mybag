#if os(macOS)
import Foundation
import Security
import Network

/// Provides the TLS server identity (self-signed) the agent's listener presents.
/// The key/cert are generated locally on first run (via `openssl`) under `~/.mitm` and are
/// never committed. Real peer authentication is layered on top via ECDH pairing (DG-3).
public enum ServerIdentity {

    public static func loadOrCreate() -> sec_identity_t? {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mitm", isDirectory: true)
        let p12URL = directory.appendingPathComponent("identity.p12")

        if !FileManager.default.fileExists(atPath: p12URL.path) {
            guard generateP12(in: directory) else { return nil }
        }
        guard let data = try? Data(contentsOf: p12URL) else { return nil }
        return makeIdentity(fromP12: data, password: "mitm")
    }

    private static func generateP12(in directory: URL) -> Bool {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let key = directory.appendingPathComponent("key.pem").path
        let cert = directory.appendingPathComponent("cert.pem").path
        let p12 = directory.appendingPathComponent("identity.p12").path

        func openssl(_ arguments: [String]) -> Bool {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do { try process.run(); process.waitUntilExit(); return process.terminationStatus == 0 }
            catch { return false }
        }

        guard openssl(["req", "-x509", "-newkey", "rsa:2048", "-keyout", key, "-out", cert,
                       "-days", "3650", "-nodes", "-subj", "/CN=Mac-In-The-Mybag"]) else { return false }
        return openssl(["pkcs12", "-export", "-inkey", key, "-in", cert, "-out", p12,
                        "-passout", "pass:mitm", "-name", "mitm"])
    }

    private static func makeIdentity(fromP12 data: Data, password: String) -> sec_identity_t? {
        let options = [kSecImportExportPassphrase as String: password] as CFDictionary
        var items: CFArray?
        guard SecPKCS12Import(data as CFData, options, &items) == errSecSuccess,
              let entries = items as? [[String: Any]],
              let identityRef = entries.first?[kSecImportItemIdentity as String] else { return nil }
        let secIdentity = identityRef as! SecIdentity
        return sec_identity_create(secIdentity)
    }
}
#endif
