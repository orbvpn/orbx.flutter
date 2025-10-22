import Flutter
import NetworkExtension

class WireGuardBridge: NSObject, FlutterPlugin {
    static let channelName = "com.orbvpn.orbx/wireguard"
    static let eventChannelName = "com.orbvpn.orbx/wireguard_state"
    
    private var vpnManager: NEVPNManager?
    private var eventSink: FlutterEventSink?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        
        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        
        let instance = WireGuardBridge()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "generateKeypair":
            generateKeypair(result: result)
            
        case "connect":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Invalid arguments",
                    details: nil
                ))
                return
            }
            connect(config: args, result: result)
            
        case "disconnect":
            disconnect(result: result)
            
        case "getStatus":
            getStatus(result: result)
            
        case "getStatistics":
            getStatistics(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // Generate WireGuard keypair
    private func generateKeypair(result: @escaping FlutterResult) {
        let privateKey = generatePrivateKey()
        let publicKey = privateKey.publicKey
        
        result([
            "privateKey": privateKey.base64Key,
            "publicKey": publicKey.base64Key
        ])
    }
    
    // Connect to WireGuard
    private func connect(config: [String: Any], result: @escaping FlutterResult) {
        loadVPNManager { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                result(FlutterError(
                    code: "LOAD_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
                return
            }
            
            guard let vpnManager = self.vpnManager else {
                result(FlutterError(
                    code: "NO_MANAGER",
                    message: "VPN Manager not initialized",
                    details: nil
                ))
                return
            }
            
            // Parse configuration
            guard let configFile = config["configFile"] as? String else {
                result(FlutterError(
                    code: "INVALID_CONFIG",
                    message: "Invalid configuration",
                    details: nil
                ))
                return
            }
            
            // Create tunnel protocol
            let tunnelProtocol = NETunnelProviderProtocol()
            tunnelProtocol.providerBundleIdentifier = "com.orbvpn.orbx.PacketTunnel"
            tunnelProtocol.serverAddress = "OrbX Server"
            
            // Pass WireGuard config
            tunnelProtocol.providerConfiguration = [
                "wgConfig": configFile
            ]
            
            vpnManager.protocolConfiguration = tunnelProtocol
            vpnManager.localizedDescription = "OrbVPN"
            vpnManager.isEnabled = true
            
            // Save configuration
            vpnManager.saveToPreferences { error in
                if let error = error {
                    result(FlutterError(
                        code: "SAVE_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                    return
                }
                
                // Start VPN
                do {
                    try vpnManager.connection.startVPNTunnel()
                    result(true)
                } catch {
                    result(FlutterError(
                        code: "START_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
    
    // Disconnect VPN
    private func disconnect(result: @escaping FlutterResult) {
        guard let vpnManager = vpnManager else {
            result(true)
            return
        }
        
        vpnManager.connection.stopVPNTunnel()
        result(true)
    }
    
    // Get connection status
    private func getStatus(result: @escaping FlutterResult) {
        guard let vpnManager = vpnManager else {
            result([
                "connected": false,
                "status": "disconnected"
            ])
            return
        }
        
        let status = vpnManager.connection.status
        let isConnected = status == .connected
        
        result([
            "connected": isConnected,
            "status": statusToString(status)
        ])
    }
    
    // Get statistics
    private func getStatistics(result: @escaping FlutterResult) {
        // iOS doesn't expose detailed statistics easily
        // We'll return placeholder values
        result([
            "bytesSent": 0,
            "bytesReceived": 0
        ])
    }
    
    // Load VPN Manager
    private func loadVPNManager(completion: @escaping (Error?) -> Void) {
        NEVPNManager.shared().loadFromPreferences { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            self?.vpnManager = NEVPNManager.shared()
            
            // Observe status changes
            NotificationCenter.default.addObserver(
                self!,
                selector: #selector(self?.vpnStatusDidChange),
                name: .NEVPNStatusDidChange,
                object: nil
            )
            
            completion(nil)
        }
    }
    
    @objc private func vpnStatusDidChange() {
        guard let vpnManager = vpnManager else { return }
        let status = statusToString(vpnManager.connection.status)
        eventSink?(status)
    }
    
    private func statusToString(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid: return "invalid"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "reasserting"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown"
        }
    }
    
    // WireGuard key generation helpers
    private func generatePrivateKey() -> PrivateKey {
        var keyData = Data(count: 32)
        keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        return PrivateKey(rawValue: keyData)!
    }
}

// Extension for FlutterStreamHandler
extension WireGuardBridge: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// WireGuard Key structures
struct PrivateKey {
    let rawValue: Data
    
    var publicKey: PublicKey {
        // Curve25519 key derivation
        var publicKeyData = Data(count: 32)
        rawValue.withUnsafeBytes { privateBytes in
            publicKeyData.withUnsafeMutableBytes { publicBytes in
                crypto_scalarmult_base(
                    publicBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    privateBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                )
            }
        }
        return PublicKey(rawValue: publicKeyData)!
    }
    
    var base64Key: String {
        return rawValue.base64EncodedString()
    }
}

struct PublicKey {
    let rawValue: Data
    
    var base64Key: String {
        return rawValue.base64EncodedString()
    }
}