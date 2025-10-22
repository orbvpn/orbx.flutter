import NetworkExtension
import WireGuardKit
import os.log

/**
 * PacketTunnelProvider for OrbVPN
 * 
 * This is the core of the iOS VPN implementation.
 * It runs in a separate process (Network Extension) and handles:
 * 1. VPN tunnel creation
 * 2. WireGuard configuration
 * 3. Packet routing
 * 4. Connection lifecycle
 */
class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let log = OSLog(subsystem: "com.orbvpn.orbx.tunnel", category: "PacketTunnel")
    
    // WireGuard adapter
    private var adapter: WireGuardAdapter?
    private var tunnelConfiguration: TunnelConfiguration?
    
    // Connection state
    private var isConnecting = false
    private var isConnected = false
    
    // Statistics timer
    private var statisticsTimer: Timer?
    
    override init() {
        super.init()
        os_log("PacketTunnelProvider initialized", log: log, type: .info)
    }
    
    // MARK: - Tunnel Lifecycle
    
    /**
     * Start the VPN tunnel
     * 
     * Called by iOS when user connects VPN from:
     * - App UI
     * - Settings > VPN
     * - Automatic reconnection
     */
    override func startTunnel(
        options: [String : NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        os_log("Starting tunnel...", log: log, type: .info)
        
        guard !isConnecting else {
            os_log("Tunnel already connecting", log: log, type: .error)
            completionHandler(TunnelError.alreadyConnecting)
            return
        }
        
        isConnecting = true
        
        // Parse configuration from options
        guard let configData = options?["config"] as? Data else {
            os_log("No configuration provided", log: log, type: .error)
            isConnecting = false
            completionHandler(TunnelError.noConfiguration)
            return
        }
        
        do {
            // Decode configuration
            let config = try JSONDecoder().decode(VPNConfiguration.self, from: configData)
            
            os_log("Config received - IP: %{public}@, Endpoint: %{public}@", 
                   log: log, type: .info, config.allocatedIp, config.serverEndpoint)
            
            // Build WireGuard configuration
            let tunnelConfig = try buildWireGuardConfiguration(from: config)
            self.tunnelConfiguration = tunnelConfig
            
            // Create WireGuard adapter
            let adapter = WireGuardAdapter(with: self) { logLevel, message in
                os_log("WireGuard: %{public}@", log: self.log, type: .debug, message)
            }
            self.adapter = adapter
            
            // Start WireGuard tunnel
            adapter.start(tunnelConfiguration: tunnelConfig) { [weak self] error in
                guard let self = self else { return }
                
                self.isConnecting = false
                
                if let error = error {
                    os_log("Failed to start WireGuard: %{public}@", 
                           log: self.log, type: .error, error.localizedDescription)
                    self.cancelTunnelWithError(error)
                    completionHandler(error)
                } else {
                    os_log("✅ WireGuard tunnel started successfully", log: self.log, type: .info)
                    self.isConnected = true
                    
                    // Start statistics monitoring
                    self.startStatisticsMonitoring()
                    
                    completionHandler(nil)
                }
            }
            
        } catch {
            os_log("Failed to configure tunnel: %{public}@", 
                   log: log, type: .error, error.localizedDescription)
            isConnecting = false
            completionHandler(error)
        }
    }
    
    /**
     * Stop the VPN tunnel
     */
    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        os_log("Stopping tunnel - reason: %{public}@", log: log, type: .info, reason.description)
        
        // Stop statistics monitoring
        statisticsTimer?.invalidate()
        statisticsTimer = nil
        
        // Stop WireGuard adapter
        adapter?.stop { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                os_log("Error stopping WireGuard: %{public}@", 
                       log: self.log, type: .error, error.localizedDescription)
            } else {
                os_log("✅ WireGuard tunnel stopped successfully", log: self.log, type: .info)
            }
            
            self.adapter = nil
            self.tunnelConfiguration = nil
            self.isConnected = false
            
            completionHandler()
        }
    }
    
    /**
     * Handle app messages
     * Used for communication between main app and tunnel extension
     */
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        os_log("Received message from app", log: log, type: .debug)
        
        guard let message = try? JSONDecoder().decode(AppMessage.self, from: messageData) else {
            os_log("Failed to decode app message", log: log, type: .error)
            completionHandler?(nil)
            return
        }
        
        switch message.type {
        case "getStatistics":
            let stats = getStatistics()
            let responseData = try? JSONEncoder().encode(stats)
            completionHandler?(responseData)
            
        case "getStatus":
            let status = TunnelStatus(
                isConnected: isConnected,
                isConnecting: isConnecting
            )
            let responseData = try? JSONEncoder().encode(status)
            completionHandler?(responseData)
            
        default:
            os_log("Unknown message type: %{public}@", log: log, type: .warning, message.type)
            completionHandler?(nil)
        }
    }
    
    /**
     * Handle sleep/wake events
     */
    override func sleep(completionHandler: @escaping () -> Void) {
        os_log("Device going to sleep", log: log, type: .info)
        // WireGuardKit handles this automatically
        completionHandler()
    }
    
    override func wake() {
        os_log("Device waking up", log: log, type: .info)
        // WireGuardKit handles this automatically
    }
    
    // MARK: - Configuration
    
    /**
     * Build WireGuard configuration from VPN config
     */
    private func buildWireGuardConfiguration(from config: VPNConfiguration) throws -> TunnelConfiguration {
        
        // Parse private key
        guard let privateKey = PrivateKey(base64Key: config.privateKey) else {
            throw TunnelError.invalidPrivateKey
        }
        
        // Parse server public key
        guard let serverPublicKey = PublicKey(base64Key: config.serverPublicKey) else {
            throw TunnelError.invalidPublicKey
        }
        
        // Parse endpoint (format: "IP:Port")
        let endpointComponents = config.serverEndpoint.split(separator: ":")
        guard endpointComponents.count == 2,
              let endpointPort = UInt16(endpointComponents[1]) else {
            throw TunnelError.invalidEndpoint
        }
        let endpointHost = String(endpointComponents[0])
        
        guard let endpoint = Endpoint(from: "\(endpointHost):\(endpointPort)") else {
            throw TunnelError.invalidEndpoint
        }
        
        // Parse allocated IP address
        guard let ipAddress = IPAddressRange(from: "\(config.allocatedIp)/24") else {
            throw TunnelError.invalidIPAddress
        }
        
        // Parse DNS servers
        let dnsServers = config.dns.compactMap { DNSServer(from: $0) }
        
        // Build Interface configuration
        let interfaceConfig = InterfaceConfiguration(
            privateKey: privateKey,
            addresses: [ipAddress],
            listenPort: nil,
            mtu: UInt16(config.mtu),
            dns: dnsServers
        )
        
        // Build Peer configuration (server)
        var peerConfig = PeerConfiguration(publicKey: serverPublicKey)
        peerConfig.endpoint = endpoint
        peerConfig.persistentKeepAlive = 25 // 25 seconds
        
        // Add allowed IPs (routes)
        // Route all IPv4 and IPv6 traffic through VPN
        peerConfig.allowedIPs = [
            IPAddressRange(from: "0.0.0.0/0")!,
            IPAddressRange(from: "::/0")!
        ]
        
        // Create tunnel configuration
        let tunnelConfig = TunnelConfiguration(
            name: "OrbVPN",
            interface: interfaceConfig,
            peers: [peerConfig]
        )
        
        return tunnelConfig
    }
    
    // MARK: - Statistics
    
    /**
     * Start monitoring connection statistics
     */
    private func startStatisticsMonitoring() {
        // Update statistics every 2 seconds
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let stats = self.getStatistics()
            
            // Send statistics to main app
            self.sendStatisticsToApp(stats)
        }
    }
    
    /**
     * Get current connection statistics
     */
    private func getStatistics() -> ConnectionStatistics {
        guard let adapter = adapter else {
            return ConnectionStatistics(
                bytesReceived: 0,
                bytesSent: 0,
                lastHandshakeTime: nil
            )
        }
        
        // Get runtime configuration (includes statistics)
        do {
            let runtimeConfig = try adapter.getRuntimeConfiguration()
            
            // WireGuard statistics are per-peer
            if let peerStats = runtimeConfig.peers.first {
                return ConnectionStatistics(
                    bytesReceived: Int64(peerStats.rxBytes),
                    bytesSent: Int64(peerStats.txBytes),
                    lastHandshakeTime: peerStats.lastHandshakeTime
                )
            }
        } catch {
            os_log("Failed to get statistics: %{public}@", 
                   log: log, type: .error, error.localizedDescription)
        }
        
        return ConnectionStatistics(
            bytesReceived: 0,
            bytesSent: 0,
            lastHandshakeTime: nil
        )
    }
    
    /**
     * Send statistics to main app
     */
    private func sendStatisticsToApp(_ stats: ConnectionStatistics) {
        guard let appGroup = UserDefaults(suiteName: "group.com.orbvpn.orbx") else {
            return
        }
        
        // Store statistics in shared container
        appGroup.set(stats.bytesReceived, forKey: "bytesReceived")
        appGroup.set(stats.bytesSent, forKey: "bytesSent")
        if let handshakeTime = stats.lastHandshakeTime {
            appGroup.set(handshakeTime.timeIntervalSince1970, forKey: "lastHandshakeTime")
        }
        appGroup.synchronize()
    }
}

// MARK: - Data Models

/**
 * VPN Configuration received from main app
 */
struct VPNConfiguration: Codable {
    let privateKey: String
    let serverPublicKey: String
    let serverEndpoint: String
    let allocatedIp: String
    let gateway: String
    let dns: [String]
    let mtu: Int
}

/**
 * Connection statistics
 */
struct ConnectionStatistics: Codable {
    let bytesReceived: Int64
    let bytesSent: Int64
    let lastHandshakeTime: Date?
}

/**
 * Tunnel status
 */
struct TunnelStatus: Codable {
    let isConnected: Bool
    let isConnecting: Bool
}

/**
 * App message
 */
struct AppMessage: Codable {
    let type: String
    let data: Data?
}

// MARK: - Errors

enum TunnelError: Error, LocalizedError {
    case noConfiguration
    case alreadyConnecting
    case invalidPrivateKey
    case invalidPublicKey
    case invalidEndpoint
    case invalidIPAddress
    
    var errorDescription: String? {
        switch self {
        case .noConfiguration:
            return "No VPN configuration provided"
        case .alreadyConnecting:
            return "Tunnel is already connecting"
        case .invalidPrivateKey:
            return "Invalid private key"
        case .invalidPublicKey:
            return "Invalid public key"
        case .invalidEndpoint:
            return "Invalid server endpoint"
        case .invalidIPAddress:
            return "Invalid IP address"
        }
    }
}

// MARK: - Extensions

extension NEProviderStopReason {
    var description: String {
        switch self {
        case .none:
            return "none"
        case .userInitiated:
            return "userInitiated"
        case .providerFailed:
            return "providerFailed"
        case .noNetworkAvailable:
            return "noNetworkAvailable"
        case .unrecoverableNetworkChange:
            return "unrecoverableNetworkChange"
        case .providerDisabled:
            return "providerDisabled"
        case .authenticationCanceled:
            return "authenticationCanceled"
        case .configurationFailed:
            return "configurationFailed"
        case .idleTimeout:
            return "idleTimeout"
        case .configurationDisabled:
            return "configurationDisabled"
        case .configurationRemoved:
            return "configurationRemoved"
        case .superceded:
            return "superceded"
        case .userLogout:
            return "userLogout"
        case .userSwitch:
            return "userSwitch"
        case .connectionFailed:
            return "connectionFailed"
        case .sleep:
            return "sleep"
        case .appUpdate:
            return "appUpdate"
        @unknown default:
            return "unknown"
        }
    }
}