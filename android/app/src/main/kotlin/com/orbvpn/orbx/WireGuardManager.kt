package com.orbvpn.orbx

import android.content.Context
import android.content.Intent
import android.util.Log
import com.wireguard.crypto.KeyPair

class WireGuardManager(private val context: Context) {
    private val TAG = "WireGuardManager"
    
    // Statistics
    private var bytesSent: Long = 0
    private var bytesReceived: Long = 0
    private var isConnected: Boolean = false
    
    // Generate WireGuard keypair
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
    
    // Connect to WireGuard server
    // Note: VPN permission must be checked BEFORE calling this method
    fun connect(configData: Map<String, Any>): Boolean {
        return try {
            Log.d(TAG, "═══════════════════════════════════════")
            Log.d(TAG, "�� WireGuardManager.connect() called")
            Log.d(TAG, "═══════════════════════════════════════")
            
            // Log config data
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
            // We do NOT check permission here because:
            // 1. Permission was already checked in MainActivity
            // 2. We only have application context, not activity context
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
            
            isConnected = true
            Log.d(TAG, "✅ VPN service start command sent successfully")
            Log.d(TAG, "═══════════════════════════════════════")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to connect to WireGuard", e)
            false
        }
    }
    
    // Disconnect from WireGuard
    fun disconnect(): Boolean {
        return try {
            Log.d(TAG, "🔻 Disconnecting from WireGuard...")
            
            val serviceIntent = Intent(context, OrbVpnService::class.java).apply {
                action = OrbVpnService.ACTION_DISCONNECT
            }
            
            context.startService(serviceIntent)
            
            isConnected = false
            Log.d(TAG, "✅ Disconnect command sent")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to disconnect", e)
            false
        }
    }
    
    // Get connection statistics
    fun getStatistics(): Map<String, Long> {
        return mapOf(
            "bytesSent" to bytesSent,
            "bytesReceived" to bytesReceived
        )
    }
    
    // Check if connected
    fun isConnected(): Boolean {
        return isConnected
    }
    
    // Get connection status as a Map with status code
    // Returns: Map with "code" key (0 = disconnected, 1 = connecting, 2 = connected)
    fun getStatus(): Map<String, Int> {
        return mapOf(
            "code" to if (isConnected) 2 else 0
        )
    }
}
