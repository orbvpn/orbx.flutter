import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    // WireGuard bridge
    private var wireguardBridge: WireGuardBridge?
    
    // Flutter channels
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Initialize WireGuard bridge
        wireguardBridge = WireGuardBridge()
        
        // Setup Flutter channels
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }
        
        setupMethodChannel(controller: controller)
        setupEventChannel(controller: controller)
        
        // Setup bridge callbacks
        setupBridgeCallbacks()
        
        // Load VPN configuration on app start
        wireguardBridge?.loadVPNConfiguration { success, error in
            if success {
                print("✅ VPN configuration loaded")
            } else {
                print("⚠️ VPN configuration not loaded: \(error?.localizedDescription ?? "unknown")")
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Flutter Method Channel
    
    private func setupMethodChannel(controller: FlutterViewController) {
        methodChannel = FlutterMethodChannel(
            name: "com.orbvpn.orbx/vpn",
            binaryMessenger: controller.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            print("📞 Method call: \(call.method)")
            
            switch call.method {
            case "generateKeypair":
                self.handleGenerateKeypair(result: result)
                
            case "connect":
                self.handleConnect(call: call, result: result)
                
            case "disconnect":
                self.handleDisconnect(result: result)
                
            case "getStatus":
                self.handleGetStatus(result: result)
                
            case "getStatistics":
                self.handleGetStatistics(result: result)
                
            case "requestVPNPermission":
                self.handleRequestVPNPermission(result: result)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Flutter Event Channel
    
    private func setupEventChannel(controller: FlutterViewController) {
        eventChannel = FlutterEventChannel(
            name: "com.orbvpn.orbx/vpn_state",
            binaryMessenger: controller.binaryMessenger
        )
        
        eventChannel?.setStreamHandler(self)
    }
    
    // MARK: - Bridge Callbacks
    
    private func setupBridgeCallbacks() {
        // Status change callback
        wireguardBridge?.onStatusChanged = { [weak self] status in
            print("📡 Status changed: \(status)")
            
            self?.eventSink?([
                "state": status
            ])
        }
        
        // Statistics update callback
        wireguardBridge?.onStatisticsUpdated = { [weak self] bytesReceived, bytesSent in
            self?.eventSink?([
                "state": "connected",
                "bytesReceived": bytesReceived,
                "bytesSent": bytesSent
            ])
        }
    }
    
    // MARK: - Method Handlers
    
    private func handleGenerateKeypair(result: @escaping FlutterResult) {
        guard let bridge = wireguardBridge else {
            result(FlutterError(
                code: "BRIDGE_ERROR",
                message: "WireGuard bridge not initialized",
                details: nil
            ))
            return
        }
        
        let keypair = bridge.generateKeypair()
        result(keypair)
    }
    
    private func handleConnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let bridge = wireguardBridge else {
            result(FlutterError(
                code: "BRIDGE_ERROR",
                message: "WireGuard bridge not initialized",
                details: nil
            ))
            return
        }
        
        guard let config = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Invalid configuration",
                details: nil
            ))
            return
        }
        
        print("🔌 Connecting with config: \(config.keys)")
        
        // Send connecting state
        eventSink?(["state": "connecting"])
        
        bridge.connect(config: config) { [weak self] success, error in
            if success {
                print("✅ Connection successful")
                result(true)
                self?.eventSink?(["state": "connected"])
            } else {
                print("❌ Connection failed: \(error?.localizedDescription ?? "unknown")")
                result(FlutterError(
                    code: "CONNECT_ERROR",
                    message: error?.localizedDescription ?? "Connection failed",
                    details: nil
                ))
                self?.eventSink?(["state": "error", "error": error?.localizedDescription ?? "Connection failed"])
            }
        }
    }
    
    private func handleDisconnect(result: @escaping FlutterResult) {
        guard let bridge = wireguardBridge else {
            result(FlutterError(
                code: "BRIDGE_ERROR",
                message: "WireGuard bridge not initialized",
                details: nil
            ))
            return
        }
        
        print("🔌 Disconnecting...")
        
        // Send disconnecting state
        eventSink?(["state": "disconnecting"])
        
        bridge.disconnect { [weak self] success in
            result(success)
            self?.eventSink?(["state": "disconnected"])
        }
    }
    
    private func handleGetStatus(result: @escaping FlutterResult) {
        guard let bridge = wireguardBridge else {
            result(FlutterError(
                code: "BRIDGE_ERROR",
                message: "WireGuard bridge not initialized",
                details: nil
            ))
            return
        }
        
        let status = bridge.getConnectionStatus()
        result([
            "connected": status == "connected",
            "state": status
        ])
    }
    
    private func handleGetStatistics(result: @escaping FlutterResult) {
        guard let bridge = wireguardBridge else {
            result(FlutterError(
                code: "BRIDGE_ERROR",
                message: "WireGuard bridge not initialized",
                details: nil
            ))
            return
        }
        
        let stats = bridge.getStatistics()
        result(stats)
    }
    
    private func handleRequestVPNPermission(result: @escaping FlutterResult) {
        guard let bridge = wireguardBridge else {
            result(FlutterError(
                code: "BRIDGE_ERROR",
                message: "WireGuard bridge not initialized",
                details: nil
            ))
            return
        }
        
        bridge.requestVPNPermission { success in
            result(success)
        }
    }
}

// MARK: - FlutterStreamHandler

extension AppDelegate: FlutterStreamHandler {
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("📡 Event channel listener attached")
        self.eventSink = events
        
        // Send initial state
        if let bridge = wireguardBridge {
            let status = bridge.getConnectionStatus()
            events(["state": status])
        }
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("📡 Event channel listener cancelled")
        self.eventSink = nil
        return nil
    }
}