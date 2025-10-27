package com.orbvpn.orbx

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*

/**
 * Connection Manager
 * 
 * Handles intelligent protocol selection and auto-switching:
 * 1. Tests which mimicry protocol wrapper is reachable
 * 2. Connects VPN through that wrapper
 * 3. Tests if internet actually works
 * 4. If not, automatically tries the next protocol
 */
class ConnectionManager(
    private val context: Context,
    private val wireguardManager: WireGuardManager,
    private val protocolHandler: ProtocolHandler
) {
    private val TAG = "ConnectionManager"
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    data class ConnectionConfig(
        val serverAddress: String,
        val authToken: String,
        val wireguardConfig: Map<String, Any>,
        val userRegion: String? = null
    )
    
    /**
     * Smart connect: Try protocols until one works with internet access
     */
    suspend fun connectWithAutoProtocolSelection(
        config: ConnectionConfig,
        onProgress: (String) -> Unit
    ): Boolean = withContext(Dispatchers.IO) {
        
        onProgress("Finding best protocol...")
        
        // Get protocols to try (ordered by region preference)
        val protocolsToTry = getProtocolsOrderedByPreference(config.userRegion)
        
        for (protocol in protocolsToTry) {
            try {
                onProgress("Trying ${protocol.protocolName}...")
                
                // Step 1: Test if protocol wrapper is reachable
                val testResult = protocolHandler.testProtocolReachability(
                    config.serverAddress,
                    protocol,
                    config.authToken
                )
                
                if (!testResult.isReachable) {
                    Log.d(TAG, "❌ ${protocol.protocolName} not reachable, trying next...")
                    continue
                }
                
                onProgress("${protocol.protocolName} reachable, connecting VPN...")
                
                // Step 2: Connect WireGuard through this protocol wrapper
                val wireguardConfigWithProtocol = config.wireguardConfig.toMutableMap()
                wireguardConfigWithProtocol["mimicryProtocol"] = protocol.name
                wireguardConfigWithProtocol["endpoint"] = 
                    "${config.serverAddress}:443${protocol.endpoint}"
                
                val vpnConnected = wireguardManager.connect(wireguardConfigWithProtocol)
                
                if (!vpnConnected) {
                    Log.d(TAG, "❌ VPN connection failed with ${protocol.protocolName}")
                    continue
                }
                
                onProgress("VPN connected, testing internet...")
                
                // Step 3: Wait a bit for connection to stabilize
                delay(2000)
                
                // Step 4: Test if internet actually works
                val internetWorks = protocolHandler.testInternetConnectivity(protocol)
                
                if (!internetWorks) {
                    Log.w(TAG, "❌ Internet not working through ${protocol.protocolName}, disconnecting...")
                    wireguardManager.disconnect()
                    continue
                }
                
                // SUCCESS!
                Log.i(TAG, "✅ Successfully connected through ${protocol.protocolName}")
                onProgress("Connected via ${protocol.protocolName}")
                return@withContext true
                
            } catch (e: Exception) {
                Log.e(TAG, "Error trying ${protocol.protocolName}", e)
                wireguardManager.disconnect()
                continue
            }
        }
        
        // No protocol worked
        Log.e(TAG, "❌ No protocols worked")
        onProgress("Connection failed - all protocols blocked")
        return@withContext false
    }
    
    /**
     * Get protocols ordered by preference for a region
     */
    private fun getProtocolsOrderedByPreference(
        userRegion: String?
    ): List<ProtocolHandler.MimicryProtocol> {
        
        val allProtocols = ProtocolHandler.MimicryProtocol.values().toList()
        
        if (userRegion == null) {
            return allProtocols
        }
        
        return allProtocols.sortedByDescending { protocol ->
            when {
                // Exact region match = highest priority
                protocol.regions.contains(userRegion) -> 3
                // Universal protocols = medium priority
                protocol.regions.contains("*") -> 2
                // Others = low priority
                else -> 1
            }
        }
    }
    
    /**
     * Monitor connection and auto-switch if it fails
     */
    fun startConnectionMonitoring(
        config: ConnectionConfig,
        onConnectionLost: () -> Unit,
        onReconnected: () -> Unit
    ) {
        scope.launch {
            while (isActive) {
                delay(30000) // Check every 30 seconds
                
                val status = wireguardManager.getStatus()
                val isConnected = status["connected"] as? Boolean ?: false
                
                if (!isConnected) {
                    Log.w(TAG, "Connection lost, attempting to reconnect...")
                    onConnectionLost()
                    
                    val reconnected = connectWithAutoProtocolSelection(config) { progress ->
                        Log.d(TAG, "Reconnect progress: $progress")
                    }
                    
                    if (reconnected) {
                        onReconnected()
                    }
                }
            }
        }
    }
    
    /**
     * Stop connection monitoring (alias for stopMonitoring)
     */
    fun stopConnectionMonitoring() {
        stopMonitoring()
    }
    
    /**
     * Stop connection monitoring
     */
    fun stopMonitoring() {
        scope.cancel()
        Log.d(TAG, "Connection monitoring stopped")
    }
}