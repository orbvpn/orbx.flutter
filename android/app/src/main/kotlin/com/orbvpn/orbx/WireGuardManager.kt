package com.orbvpn.orbx

import android.content.Context
import android.content.Intent
import android.net.VpnService
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
            mapOf(
                "privateKey" to keypair.privateKey.toBase64(),
                "publicKey" to keypair.publicKey.toBase64()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate keypair", e)
            mapOf(
                "privateKey" to "",
                "publicKey" to ""
            )
        }
    }
    
// Connect to WireGuard server
fun connect(configData: Map<String, Any>): Boolean {
    return try {
        Log.d(TAG, "Connecting to WireGuard...")
        
        // Start VPN service
        val serviceIntent = Intent(context, OrbVpnService::class.java).apply {
            action = OrbVpnService.ACTION_CONNECT
            putExtra(OrbVpnService.EXTRA_CONFIG, HashMap(configData))
        }
        
        context.startForegroundService(serviceIntent)
        
        isConnected = true
        Log.d(TAG, "VPN service started successfully")
        true
        
    } catch (e: Exception) {
        Log.e(TAG, "Failed to connect", e)
        false
    }
}
    
// Disconnect from WireGuard
fun disconnect(): Boolean {
    return try {
        Log.d(TAG, "Disconnecting from WireGuard...")
        
        val serviceIntent = Intent(context, OrbVpnService::class.java).apply {
            action = OrbVpnService.ACTION_DISCONNECT
        }
        
        context.startService(serviceIntent)
        
        isConnected = false
        Log.d(TAG, "VPN service stop requested")
        true
        
    } catch (e: Exception) {
        Log.e(TAG, "Failed to disconnect", e)
        false
    }
}

// Add this method to check actual connection status
fun getConnectionStatus(): Map<String, Any> {
    return mapOf(
        "isConnected" to isConnected,
        "bytesSent" to bytesSent,
        "bytesReceived" to bytesReceived
    )
}
    
    // Get connection status
    fun getStatus(): Map<String, Any> {
        return mapOf(
            "connected" to isConnected,
            "tunnel" to if (isConnected) "wg0" else ""
        )
    }
    
    // Get statistics
    fun getStatistics(): Map<String, Long> {
        return mapOf(
            "bytesSent" to bytesSent,
            "bytesReceived" to bytesReceived
        )
    }
    
    // Update statistics (called by VPN service)
    fun updateStatistics(sent: Long, received: Long) {
        bytesSent = sent
        bytesReceived = received
    }
}