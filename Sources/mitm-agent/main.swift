import Foundation

#if os(macOS)
import MacOSAgent

let port: UInt16 = {
    if let raw = ProcessInfo.processInfo.environment["MITM_PORT"], let value = UInt16(raw) { return value }
    return 7000
}()

let agent = Agent(port: port)

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
