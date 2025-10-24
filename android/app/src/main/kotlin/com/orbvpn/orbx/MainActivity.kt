package com.orbvpn.orbx

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import android.util.Log

/**
 * MainActivity for OrbX VPN
 * 
 * Handles communication between Flutter and native Android VPN functionality
 * Supports:
 * - WireGuard VPN connection with protocol mimicry
 * - Smart protocol selection and auto-switching
 * - VPN state monitoring and statistics
 */
class MainActivity : FlutterActivity() {
    
    private val TAG = "MainActivity"
    
    // Channel names for Flutter communication
    private val CHANNEL = "com.orbvpn.orbx/vpn"
    private val EVENT_CHANNEL = "com.orbvpn.orbx/vpn_state"
    
    // VPN permission request code
    private val VPN_REQUEST_CODE = 1001
    
    // Managers
    private lateinit var wireguardManager: WireGuardManager
    private lateinit var protocolHandler: ProtocolHandler
    private lateinit var connectionManager: ConnectionManager
    
    // Method call result waiting for VPN permission
    private var pendingResult: MethodChannel.Result? = null
    private var pendingConfig: Map<String, Any>? = null
    
    // Event sink for state changes
    private var eventSink: EventChannel.EventSink? = null
    
    // Coroutine scope for async operations
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "OrbX MainActivity created")
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "Configuring Flutter engine")
        
// Initialize managers
// IMPORTANT: Use 'this' (Activity context) for VPN permission checks
wireguardManager = WireGuardManager(this)
protocolHandler = ProtocolHandler(this)
connectionManager = ConnectionManager(
    this,
    wireguardManager,
    protocolHandler
)
        
        // Setup Method Channel (for function calls from Flutter)
        setupMethodChannel(flutterEngine)
        
        // Setup Event Channel (for state updates to Flutter)
        setupEventChannel(flutterEngine)
        
        Log.d(TAG, "Flutter engine configured successfully")
    }
    
    /**
     * Setup Method Channel for Flutter → Android calls
     */
    private fun setupMethodChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            
            Log.d(TAG, "Method call received: ${call.method}")
            
            when (call.method) {
                
                // Generate WireGuard keypair
                "generateKeypair" -> {
                    try {
                        val keypair = wireguardManager.generateKeypair()
                        result.success(keypair)
                        Log.d(TAG, "Keypair generated successfully")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to generate keypair", e)
                        result.error("KEYPAIR_ERROR", e.message, null)
                    }
                }
                
                // Basic connect (without smart protocol selection)
                "connect" -> {
                    val config = call.arguments as? Map<String, Any>
                    
                    if (config == null) {
                        result.error("INVALID_ARGS", "Configuration is required", null)
                        return@setMethodCallHandler
                    }
                    
                    // Check VPN permission
                    val intent = VpnService.prepare(applicationContext)
                    if (intent != null) {
                        // Need permission - save result and config for later
                        pendingResult = result
                        pendingConfig = config
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                        Log.d(TAG, "Requesting VPN permission")
                    } else {
                        // Permission already granted
                        connectVPN(config, result)
                    }
                }
                
                // Smart connect with auto protocol selection
                "smartConnect" -> {
                    val args = call.arguments as? Map<String, Any>
                    
                    if (args == null) {
                        result.error("INVALID_ARGS", "Configuration is required", null)
                        return@setMethodCallHandler
                    }
                    
                    // Check VPN permission first
                    val intent = VpnService.prepare(applicationContext)
                    if (intent != null) {
                        pendingResult = result
                        pendingConfig = args
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                        return@setMethodCallHandler
                    }
                    
                    // Extract configuration
                    val serverAddress = args["serverAddress"] as? String
                    val authToken = args["authToken"] as? String
                    val wireguardConfig = args["wireguardConfig"] as? Map<String, Any>
                    val userRegion = args["userRegion"] as? String
                    
                    if (serverAddress == null || authToken == null || wireguardConfig == null) {
                        result.error("INVALID_ARGS", "Missing required parameters", null)
                        return@setMethodCallHandler
                    }
                    
                    Log.d(TAG, "Starting smart connect to $serverAddress (region: $userRegion)")
                    
                    // Execute smart connect in background
                    scope.launch {
                        try {
                            val config = ConnectionManager.ConnectionConfig(
                                serverAddress = serverAddress,
                                authToken = authToken,
                                wireguardConfig = wireguardConfig,
                                userRegion = userRegion
                            )
                            
                            val success = connectionManager.connectWithAutoProtocolSelection(config) { progress ->
                                // Send progress updates to Flutter
                                sendStateUpdate(mapOf(
                                    "state" to "connecting",
                                    "progress" to progress
                                ))
                            }
                            
                            withContext(Dispatchers.Main) {
                                if (success) {
                                    // Start VPN foreground service
                                    startVpnService()
                                    
                                    // Start connection monitoring
                                    startConnectionMonitoring(config)
                                    
                                    result.success(true)
                                    sendStateUpdate(mapOf("state" to "connected"))
                                } else {
                                    result.success(false)
                                    sendStateUpdate(mapOf("state" to "disconnected"))
                                }
                            }
                            
                        } catch (e: Exception) {
                            Log.e(TAG, "Smart connect failed", e)
                            withContext(Dispatchers.Main) {
                                result.error("CONNECT_ERROR", e.message, null)
                                sendStateUpdate(mapOf("state" to "error", "error" to e.message))
                            }
                        }
                    }
                }
                
                // Disconnect VPN
"disconnect" -> {
    try {
        Log.d(TAG, "Disconnect requested")
        
        // Stop foreground service
        val serviceIntent = Intent(applicationContext, OrbVpnService::class.java)
        stopService(serviceIntent)
        
        // Disconnect WireGuard
        val success = wireguardManager.disconnect()
        result.success(success)
        
        // Send state update
        sendStateUpdate(mapOf("state" to "disconnected"))
        
        Log.d(TAG, "Disconnect completed")
        
    } catch (e: Exception) {
        Log.e(TAG, "Failed to disconnect", e)
        result.error("DISCONNECT_ERROR", e.message, null)
    }
}
                
                // Get connection status
                "getStatus" -> {
                    try {
                        val status = wireguardManager.getStatus()
                        result.success(status)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to get status", e)
                        result.error("STATUS_ERROR", e.message, null)
                    }
                }
                
                // Get connection statistics
                "getStatistics" -> {
                    try {
                        val stats = wireguardManager.getStatistics()
                        result.success(stats)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to get statistics", e)
                        result.error("STATS_ERROR", e.message, null)
                    }
                }
                
                // Test a specific protocol
                "testProtocol" -> {
                    val serverAddress = call.argument<String>("serverAddress")
                    val protocolName = call.argument<String>("protocol")
                    val authToken = call.argument<String>("authToken")
                    
                    if (serverAddress == null || protocolName == null || authToken == null) {
                        result.error("INVALID_ARGS", "Missing required parameters", null)
                        return@setMethodCallHandler
                    }
                    
                    scope.launch {
                        try {
                            val protocol = protocolHandler.getProtocolByName(protocolName)
                            
                            if (protocol == null) {
                                withContext(Dispatchers.Main) {
                                    result.error("INVALID_PROTOCOL", "Unknown protocol: $protocolName", null)
                                }
                                return@launch
                            }
                            
                            val testResult = protocolHandler.testProtocolReachability(
                                serverAddress,
                                protocol,
                                authToken
                            )
                            
                            withContext(Dispatchers.Main) {
                                result.success(mapOf(
                                    "protocol" to protocolName,
                                    "reachable" to testResult.isReachable,
                                    "latency" to testResult.latencyMs,
                                    "error" to testResult.errorMessage
                                ))
                            }
                            
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("TEST_ERROR", e.message, null)
                            }
                        }
                    }
                }
                
                // Test all protocols
                "testAllProtocols" -> {
                    val serverAddress = call.argument<String>("serverAddress")
                    val authToken = call.argument<String>("authToken")
                    
                    if (serverAddress == null || authToken == null) {
                        result.error("INVALID_ARGS", "Missing required parameters", null)
                        return@setMethodCallHandler
                    }
                    
                    scope.launch {
                        try {
                            val protocols = ProtocolHandler.MimicryProtocol.values()
                            val results = mutableListOf<Map<String, Any?>>()
                            
                            for (protocol in protocols) {
                                val testResult = protocolHandler.testProtocolReachability(
                                    serverAddress,
                                    protocol,
                                    authToken
                                )
                                
                                results.add(mapOf(
                                    "protocol" to protocol.name,
                                    "displayName" to protocol.protocolName,
                                    "reachable" to testResult.isReachable,
                                    "latency" to testResult.latencyMs,
                                    "error" to testResult.errorMessage
                                ))
                            }
                            
                            withContext(Dispatchers.Main) {
                                result.success(results)
                            }
                            
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("TEST_ERROR", e.message, null)
                            }
                        }
                    }
                }
                
                // Get all available protocols
                "getAvailableProtocols" -> {
                    try {
                        val protocols = protocolHandler.getAllProtocols()
                        result.success(protocols)
                    } catch (e: Exception) {
                        result.error("PROTOCOLS_ERROR", e.message, null)
                    }
                }
                
                // Unknown method
                else -> {
                    Log.w(TAG, "Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }
    
    /**
     * Setup Event Channel for Android → Flutter state updates
     */
    private fun setupEventChannel(flutterEngine: FlutterEngine) {
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.d(TAG, "Event channel listener attached")
                eventSink = events
                
                // Send initial state
                val status = wireguardManager.getStatus()
                events?.success(mapOf(
                    "state" to if (status["connected"] as Boolean) "connected" else "disconnected"
                ))
            }
            
            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "Event channel listener cancelled")
                eventSink = null
            }
        })
    }
    
    /**
     * Connect VPN (basic connection without smart protocol selection)
     */
    private fun connectVPN(config: Map<String, Any>, result: MethodChannel.Result) {
        scope.launch {
            try {
                Log.d(TAG, "Connecting VPN with basic method")
                
                sendStateUpdate(mapOf("state" to "connecting"))
                
                val success = wireguardManager.connect(config)
                
                withContext(Dispatchers.Main) {
                    if (success) {
                        startVpnService()
                        result.success(true)
                        sendStateUpdate(mapOf("state" to "connected"))
                        Log.d(TAG, "VPN connected successfully")
                    } else {
                        result.success(false)
                        sendStateUpdate(mapOf("state" to "disconnected"))
                        Log.w(TAG, "VPN connection failed")
                    }
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "VPN connection error", e)
                withContext(Dispatchers.Main) {
                    result.error("CONNECT_ERROR", e.message, null)
                    sendStateUpdate(mapOf("state" to "error", "error" to e.message))
                }
            }
        }
    }
    
    /**
     * Start VPN foreground service
     */
    private fun startVpnService() {
        val serviceIntent = Intent(this, OrbVpnService::class.java).apply {
            action = OrbVpnService.ACTION_CONNECT
        }
        startForegroundService(serviceIntent)
        Log.d(TAG, "VPN foreground service started")
    }
    
    /**
     * Stop VPN foreground service
     */
    private fun stopVpnService() {
        val serviceIntent = Intent(this, OrbVpnService::class.java)
        stopService(serviceIntent)
        Log.d(TAG, "VPN foreground service stopped")
    }
    
    /**
     * Start monitoring connection and auto-reconnect if needed
     */
    private fun startConnectionMonitoring(config: ConnectionManager.ConnectionConfig) {
        connectionManager.startConnectionMonitoring(
            config,
            onConnectionLost = {
                Log.w(TAG, "Connection lost - attempting to reconnect")
                sendStateUpdate(mapOf("state" to "reconnecting"))
            },
            onReconnected = {
                Log.i(TAG, "Reconnected successfully")
                sendStateUpdate(mapOf("state" to "connected"))
            }
        )
    }
    
    /**
     * Send state update to Flutter via Event Channel
     */
    private fun sendStateUpdate(state: Map<String, Any?>) {
        eventSink?.success(state)
    }
    
    /**
     * Handle VPN permission result
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                Log.d(TAG, "VPN permission granted")
                
                // Permission granted - proceed with connection
                val result = pendingResult
                val config = pendingConfig
                
                if (result != null && config != null) {
                    // Check if this is a smart connect or basic connect
                    if (config.containsKey("serverAddress")) {
                        // Smart connect
                        val serverAddress = config["serverAddress"] as String
                        val authToken = config["authToken"] as String
                        val wireguardConfig = config["wireguardConfig"] as Map<String, Any>
                        val userRegion = config["userRegion"] as? String
                        
                        scope.launch {
                            try {
                                val connectionConfig = ConnectionManager.ConnectionConfig(
                                    serverAddress = serverAddress,
                                    authToken = authToken,
                                    wireguardConfig = wireguardConfig,
                                    userRegion = userRegion
                                )
                                
                                val success = connectionManager.connectWithAutoProtocolSelection(connectionConfig) { progress ->
                                    sendStateUpdate(mapOf("state" to "connecting", "progress" to progress))
                                }
                                
                                withContext(Dispatchers.Main) {
                                    if (success) {
                                        startVpnService()
                                        startConnectionMonitoring(connectionConfig)
                                        result.success(true)
                                        sendStateUpdate(mapOf("state" to "connected"))
                                    } else {
                                        result.success(false)
                                        sendStateUpdate(mapOf("state" to "disconnected"))
                                    }
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("CONNECT_ERROR", e.message, null)
                                }
                            }
                        }
                    } else {
                        // Basic connect
                        connectVPN(config, result)
                    }
                }
                
            } else {
                Log.w(TAG, "VPN permission denied")
                pendingResult?.error("PERMISSION_DENIED", "VPN permission was denied", null)
            }
            
            // Clear pending data
            pendingResult = null
            pendingConfig = null
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        // Clean up
        scope.cancel()
        connectionManager.stopMonitoring()
        
        Log.d(TAG, "MainActivity destroyed")
    }
}