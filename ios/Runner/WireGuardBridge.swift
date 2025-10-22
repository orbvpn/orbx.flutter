import Foundation
import NetworkExtension
import WireGuardKit

/**
 * WireGuardBridge for iOS
 * 
 * This class handles communication between Flutter and iOS VPN functionality.
 * It provides methods for:
 * 1. Keypair generation
 * 2. VPN connection/disconnection
 * 3. Status monitoring
 * 4. Statistics retrieval
 */
class WireGuardBridge: NSObject {
    
    // VPN manager
    private var vpnManager: NETunnelProviderManager?
    
    // Connection state observers
    private var statusObserver: NSObjectProtocol?
    
    // Callbacks
    var onStatusChanged: ((String) -> Void)?
    var onStatisticsUpdated: ((Int64, Int64) -> Void)?
    
    // Shared UserDefaults for statistics
    private let sharedDefaults = UserDefaults(suiteName: "group.com.orbvpn.orbx")
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupNotificationObservers()
    }
    
    deinit {
        removeNotificationObservers()
    }
    
    // MARK: - Keypair Generation
    
    /**
     * Generate WireGuard keypair
     */
    func generateKeypair() -> [String: String] {
        let privateKey = PrivateKey()
        let publicKey = privateKey.publicKey
        
        return [
            "privateKey": privateKey.base64Key,
            "publicKey": publicKey.base64Key
        ]
    }
    
    // MARK: - VPN Connection
    
    /**
     * Load VPN configuration
     * Must be called before connect()
     */
    func loadVPNConfiguration(completion: @escaping (Bool, Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to load VPN configuration: \(error)")
                completion(false, error)
                return
            }
            
            // Use existing configuration or create new one
            if let manager = managers?.first {
                self.vpnManager = manager
                print("✅ Loaded existing VPN configuration")
                completion(true, nil)
            } else {
                // Create new VPN configuration
                self.createVPNConfiguration(completion: completion)
            }
        }
    }
    
    /**
     * Create new VPN configuration
     */
    private func createVPNConfiguration(completion: @escaping (Bool, Error?) -> Void) {
        let manager = NETunnelProviderManager()
        
        // Protocol configuration
        let protocolConfig = NETunnelProviderProtocol()
        protocolConfig.providerBundleIdentifier = "com.orbvpn.orbx.tunnel" // Network Extension bundle ID
        protocolConfig.serverAddress = "OrbVPN" // Display name
        
        manager.protocolConfiguration = protocolConfig
        manager.localizedDescription = "OrbVPN"
        
        // Enable VPN on demand
        manager.isOnDemandEnabled = false // User must manually connect
        manager.isEnabled = true
        
        // Save configuration
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                print("❌ Failed to save VPN configuration: \(error)")
                completion(false, error)
            } else {
                self?.vpnManager = manager
                print("✅ Created new VPN configuration")
                
                // Reload to get the configuration ID
                manager.loadFromPreferences { error in
                    if let error = error {
                        print("⚠️ Failed to reload configuration: \(error)")
                    }
                    completion(true, nil)
                }
            }
        }
    }
    
    /**
     * Connect to VPN
     */
    func connect(config: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        guard let manager = vpnManager else {
            let error = NSError(
                domain: "WireGuardBridge",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "VPN manager not initialized. Call loadVPNConfiguration() first."]
            )
            completion(false, error)
            return
        }
        
        // Encode configuration
        guard let configData = try? JSONEncoder().encode(config) else {
            let error = NSError(
                domain: "WireGuardBridge",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode configuration"]
            )
            completion(false, error)
            return
        }
        
        // Start VPN tunnel
        do {
            let options = [
                "config": configData as NSObject
            ]
            
            try manager.connection.startVPNTunnel(options: options)
            
            print("✅ VPN tunnel start requested")
            
            // Wait for connection to establish (up to 10 seconds)
            waitForConnection(timeout: 10.0) { success in
                completion(success, nil)
            }
            
        } catch {
            print("❌ Failed to start VPN tunnel: \(error)")
            completion(false, error)
        }
    }
    
    /**
     * Wait for VPN connection to establish
     */
    private func waitForConnection(timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        let startTime = Date()
        let checkInterval: TimeInterval = 0.5
        
        Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                completion(false)
                return
            }
            
            let status = self.getConnectionStatus()
            
            if status == "connected" {
                timer.invalidate()
                completion(true)
            } else if Date().timeIntervalSince(startTime) > timeout {
                timer.invalidate()
                print("⚠️ Connection timeout")
                completion(false)
            }
        }
    }
    
    /**
     * Disconnect from VPN
     */
    func disconnect(completion: @escaping (Bool) -> Void) {
        guard let manager = vpnManager else {
            print("⚠️ VPN manager not initialized")
            completion(false)
            return
        }
        
        manager.connection.stopVPNTunnel()
        print("✅ VPN tunnel stop requested")
        
        // Wait for disconnection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
    
    // MARK: - Status & Statistics
    
    /**
     * Get connection status
     */
    func getConnectionStatus() -> String {
        guard let connection = vpnManager?.connection else {
            return "disconnected"
        }
        
        switch connection.status {
        case .invalid:
            return "invalid"
        case .disconnected:
            return "disconnected"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .reasserting:
            return "reconnecting"
        case .disconnecting:
            return "disconnecting"
        @unknown default:
            return "unknown"
        }
    }
    
    /**
     * Get connection statistics
     */
    func getStatistics() -> [String: Int64] {
        guard let sharedDefaults = sharedDefaults else {
            return [
                "bytesReceived": 0,
                "bytesSent": 0,
                "lastHandshakeTime": 0
            ]
        }
        
        let bytesReceived = sharedDefaults.integer(forKey: "bytesReceived")
        let bytesSent = sharedDefaults.integer(forKey: "bytesSent")
        let lastHandshakeTime = sharedDefaults.double(forKey: "lastHandshakeTime")
        
        return [
            "bytesReceived": Int64(bytesReceived),
            "bytesSent": Int64(bytesSent),
            "lastHandshakeTime": Int64(lastHandshakeTime)
        ]
    }
    
    /**
     * Send message to tunnel provider
     */
    func sendMessageToTunnel(message: [String: Any], completion: @escaping (Data?) -> Void) {
        guard let session = vpnManager?.connection as? NETunnelProviderSession else {
            print("❌ No active tunnel session")
            completion(nil)
            return
        }
        
        guard let messageData = try? JSONEncoder().encode(message) else {
            print("❌ Failed to encode message")
            completion(nil)
            return
        }
        
        do {
            try session.sendProviderMessage(messageData) { response in
                completion(response)
            }
        } catch {
            print("❌ Failed to send message to tunnel: \(error)")
            completion(nil)
        }
    }
    
    // MARK: - Notification Observers
    
    /**
     * Setup notification observers for VPN status changes
     */
    private func setupNotificationObservers() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            let status = self.getConnectionStatus()
            print("📡 VPN status changed: \(status)")
            
            // Notify Flutter
            self.onStatusChanged?(status)
            
            // Update statistics when connected
            if status == "connected" {
                self.startStatisticsPolling()
            } else {
                self.stopStatisticsPolling()
            }
        }
    }
    
    /**
     * Remove notification observers
     */
    private func removeNotificationObservers() {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Statistics Polling
    
    private var statisticsTimer: Timer?
    
    /**
     * Start polling statistics from tunnel
     */
    private func startStatisticsPolling() {
        stopStatisticsPolling() // Clear any existing timer
        
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let stats = self.getStatistics()
            let bytesReceived = stats["bytesReceived"] ?? 0
            let bytesSent = stats["bytesSent"] ?? 0
            
            self.onStatisticsUpdated?(bytesReceived, bytesSent)
        }
    }
    
    /**
     * Stop polling statistics
     */
    private func stopStatisticsPolling() {
        statisticsTimer?.invalidate()
        statisticsTimer = nil
    }
    
    // MARK: - VPN Permission
    
    /**
     * Check if VPN permission is granted
     */
    func hasVPNPermission() -> Bool {
        return vpnManager != nil
    }
    
    /**
     * Request VPN permission
     * 
     * On iOS, permission is granted when user approves the VPN configuration
     */
    func requestVPNPermission(completion: @escaping (Bool) -> Void) {
        loadVPNConfiguration { success, error in
            if success {
                print("✅ VPN permission granted")
                completion(true)
            } else {
                print("❌ VPN permission denied: \(error?.localizedDescription ?? "unknown error")")
                completion(false)
            }
        }
    }
}