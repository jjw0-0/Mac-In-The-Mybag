#if os(macOS)
import Foundation
import Darwin

/// Enumerates the host's IPv4 addresses, for building pairing connection hints (DG-2).
public enum LocalNetwork {
    public static func ipv4Addresses() -> [String] {
        var addresses: [String] = []
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let first = ifaddrPointer else { return [] }
        defer { freeifaddrs(ifaddrPointer) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let node = cursor {
            defer { cursor = node.pointee.ifa_next }
            guard let addr = node.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: node.pointee.ifa_name)
            guard name != "lo0" else { continue } // skip loopback

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                     &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            if result == 0 {
                let ip = String(cString: host)
                if !ip.isEmpty, !addresses.contains(ip) { addresses.append(ip) }
            }
        }
        return addresses
    }
}
#endif
