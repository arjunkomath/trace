import Foundation
import Network
import AppKit
import os.log

class NetworkUtilities {
    static let shared = NetworkUtilities()
    private let logger = AppLogger.networkUtilities
    
    // Cache for IP addresses with timestamps
    private var cachedPublicIP: (ip: String, timestamp: Date)?
    private var cachedPrivateIP: (ip: String, timestamp: Date)?
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    private let queue = DispatchQueue(label: "com.trace.networkutilities", attributes: .concurrent)
    
    private init() {
        // NetworkUtilities initialized - public IP will be fetched only when requested
    }
    
    // MARK: - Public IP Address
    
    /// Get cached public IP if available, otherwise return nil (non-blocking)
    /// Does not trigger any network requests - purely reads from cache
    func getCachedPublicIP() -> String? {
        return queue.sync {
            guard let cached = cachedPublicIP else { return nil }
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                return cached.ip
            } else {
                // Cache expired, clear it but don't auto-refresh
                cachedPublicIP = nil
                return nil
            }
        }
    }
    
    
    /// Get public IP address (async, always fresh)
    func getPublicIPAddress() async -> String? {
        if let ip = await fetchPublicIPAddress() {
            queue.async(flags: .barrier) {
                self.cachedPublicIP = (ip: ip, timestamp: Date())
            }
            return ip
        }
        return nil
    }
    
    private func fetchPublicIPAddress() async -> String? {
        // Try multiple services for reliability
        let services = [
            "https://api.ipify.org",
            "https://ipv4.icanhazip.com",
            "https://checkip.amazonaws.com"
        ]
        
        for service in services {
            if let ip = await fetchIPFromService(url: service) {
                logger.info("Successfully retrieved public IP from \(service): \(ip)")
                return ip.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        logger.error("Failed to retrieve public IP from all services")
        return nil
    }
    
    private func fetchIPFromService(url: String) async -> String? {
        guard let url = URL(string: url) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let ipString = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate IP format
            if let ip = ipString, isValidIPAddress(ip) {
                return ip
            }
        } catch {
            logger.debug("Failed to fetch IP from \(url.absoluteString): \(error)")
        }
        
        return nil
    }
    
    // MARK: - Private IP Address
    
    /// Get cached private IP if available, otherwise fetch fresh (non-blocking for cached)
    func getCachedPrivateIP() -> String? {
        return queue.sync {
            if let cached = cachedPrivateIP {
                let age = Date().timeIntervalSince(cached.timestamp)
                if age < cacheTimeout {
                    return cached.ip
                }
            }
            
            // Cache miss or expired, fetch fresh
            if let ip = fetchPrivateIPAddress() {
                cachedPrivateIP = (ip: ip, timestamp: Date())
                return ip
            }
            return nil
        }
    }
    
    func getPrivateIPAddress() -> String? {
        return fetchPrivateIPAddress()
    }
    
    private func fetchPrivateIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: interface.ifa_name)
                
                // Skip loopback and inactive interfaces
                if name == "lo0" || (interface.ifa_flags & UInt32(IFF_UP)) == 0 {
                    continue
                }
                
                // Prefer Wi-Fi (en0) and Ethernet (en1, en2, etc.) interfaces
                if name.hasPrefix("en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    
                    let ipAddress = String(cString: hostname)
                    
                    // Prefer IPv4 addresses and prioritize common private ranges
                    if addrFamily == UInt8(AF_INET) && isPrivateIPAddress(ipAddress) {
                        // Prioritize en0 (usually Wi-Fi) over other interfaces
                        if name == "en0" {
                            address = ipAddress
                            break
                        } else if address == nil {
                            address = ipAddress
                        }
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        
        if let ip = address {
            logger.info("Retrieved private IP address: \(ip)")
        } else {
            logger.warning("No private IP address found")
        }
        
        return address
    }
    
    // MARK: - Validation Helpers
    
    private func isValidIPAddress(_ ip: String) -> Bool {
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()
        
        return ip.withCString { cstring in
            inet_pton(AF_INET, cstring, &sin.sin_addr) == 1 ||
            inet_pton(AF_INET6, cstring, &sin6.sin6_addr) == 1
        }
    }
    
    private func isPrivateIPAddress(_ ip: String) -> Bool {
        let components = ip.components(separatedBy: ".")
        guard components.count == 4,
              let first = Int(components[0]),
              let second = Int(components[1]) else {
            return false
        }
        
        // Check private IP ranges:
        // 10.0.0.0 - 10.255.255.255
        // 172.16.0.0 - 172.31.255.255  
        // 192.168.0.0 - 192.168.255.255
        return (first == 10) ||
               (first == 172 && second >= 16 && second <= 31) ||
               (first == 192 && second == 168)
    }
    
    // MARK: - Clipboard Utilities
    
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        logger.info("Copied to clipboard: \(text)")
    }
}
