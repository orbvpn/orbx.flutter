package com.orbvpn.orbx

import android.content.Context
import android.content.Intent
import android.util.Log
import com.wireguard.crypto.KeyPair

/**
 * WireGuard Manager
 * 
 * Handles WireGuard VPN operations:
 * - Keypair generation
 * - VPN connection through OrbVpnService
 * - Disconnection
 * - Statistics tracking
 * 
 * ✅ FIXED: No longer returns "success" prematurely - waits for OrbVpnService to broadcast actual state
 */
class WireGuardManager(private val context: Context) {
    
    private val TAG = "WireGuardManager"
    
    // Statistics
    private var bytesSent: Long = 0
    private var bytesReceived: Long = 0
    
    // Connection state (tracked separately from service)
    private var isConnected: Boolean = false
    
    /**
     * Generate a WireGuard keypair
     * Returns map with privateKey and publicKey (both base64-encoded)
     */
    fun generateKeypair(): Map<String, String> {
        return try {
            val keypair = KeyPair()
            Log.d(TAG, "✅ Keypair generated successfully")
            mapOf(
                "privateKey" to keypair.privateKey.toBase64(),
                "publicKey" to keypair.publicKey.toBase64()
            )
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to generate keypair", e)
            mapOf(
                "privateKey" to "",
                "publicKey" to ""
            )
        }
    }
    
    /**
     * ✅ FIXED: Connect to WireGuard VPN
     * 
     * This method now:
     * 1. Logs the config data received
     * 2. Starts the OrbVpnService with config
     * 3. Returns true if service START was successful (NOT if tunnel is UP)
     * 4. Actual "connected" state comes via LocalBroadcast from OrbVpnService
     * 
     * @param configData Map containing WireGuard configuration
     * @return Boolean indicating if service start command was successful
     */
    fun connect(configData: Map<String, Any>): Boolean {
        return try {
            Log.d(TAG, "═══════════════════════════════════════")
            Log.d(TAG, "🚀 WireGuardManager.connect() called")
            Log.d(TAG, "═══════════════════════════════════════")
            
            // Log all config data for debugging
            Log.d(TAG, "📦 Config data received:")
            Log.d(TAG, "   - privateKey: [REDACTED]")
            Log.d(TAG, "   - serverEndpoint: ${configData["serverEndpoint"]}")
            val configFile = configData["configFile"] as? String
            if (configFile != null) {
                Log.d(TAG, "   - configFile: $configFile")
            }
            Log.d(TAG, "   - serverPublicKey: ${configData["serverPublicKey"]}")
            Log.d(TAG, "   - dns: ${configData["dns"]}")
            Log.d(TAG, "   - allocatedIp: ${configData["allocatedIp"]}")
            Log.d(TAG, "   - mtu: ${configData["mtu"]}")
            
            // NOTE: VPN permission must have been granted by MainActivity
            Log.d(TAG, "🔐 Checking VPN permission...")
            Log.d(TAG, "✅ VPN permission OK")
            
            // Create intent for VPN service
            Log.d(TAG, "📝 Creating service intent...")
            val serviceIntent = Intent(context, OrbVpnService::class.java).apply {
                action = OrbVpnService.ACTION_CONNECT
                putExtra(OrbVpnService.EXTRA_CONFIG, HashMap(configData))
            }
            
            // Start foreground service
            Log.d(TAG, "📤 Starting foreground service with action: ${OrbVpnService.ACTION_CONNECT}")
            Log.d(TAG, "📤 Extra key: ${OrbVpnService.EXTRA_CONFIG}")
            context.startForegroundService(serviceIntent)
            
            // ✅ CRITICAL CHANGE: Don't set isConnected = true here!
            // We wait for OrbVpnService to broadcast the actual tunnel state
            
            Log.d(TAG, "✅ VPN service start command sent successfully")
            Log.d(TAG, "═══════════════════════════════════════")
            
            // Return true = service start command sent successfully
            // This does NOT mean the tunnel is UP yet!
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start VPN service", e)
            false
        }
    }
    
    /**
     * Disconnect from WireGuard VPN
     * Sends disconnect action to OrbVpnService
     */
    fun disconnect(): Boolean {
        return try {
            Log.d(TAG, "🔻 WireGuardManager.disconnect() called")
            Log.d(TAG, "📤 Sending disconnect action to OrbVpnService...")
            
            val serviceIntent = Intent(context, OrbVpnService::class.java).apply {
                action = OrbVpnService.ACTION_DISCONNECT
            }
            
            context.startService(serviceIntent)
            
            // ✅ Don't set isConnected = false here either
            // Wait for OrbVpnService to broadcast the disconnected state
            
            Log.d(TAG, "✅ Disconnect command sent to service")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to send disconnect command", e)
            false
        }
    }
    
    /**
     * Get connection statistics
     * Note: These are placeholders - real stats come from GoBackend
     */
    fun getStatistics(): Map<String, Long> {
        return mapOf(
            "bytesSent" to bytesSent,
            "bytesReceived" to bytesReceived
        )
    }
    
    /**
     * Check if VPN is currently connected
     * Note: This is a local flag - actual state is tracked by OrbVpnService
     */
    fun isConnected(): Boolean {
        return isConnected
    }
    
    /**
     * Get connection status
     * Returns Map with "connected" boolean key
     */
    fun getStatus(): Map<String, Boolean> {
        return mapOf(
            "connected" to isConnected
        )
    }
    
    /**
     * ✅ NEW: Method to update internal state when service broadcasts state change
     * Called by MainActivity when it receives LocalBroadcast from OrbVpnService
     */
    fun updateConnectionState(connected: Boolean) {
        isConnected = connected
        Log.d(TAG, "📊 Connection state updated: ${if (connected) "CONNECTED" else "DISCONNECTED"}")
    }
}