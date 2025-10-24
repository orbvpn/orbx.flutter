package com.orbvpn.orbx

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import com.wireguard.config.InetNetwork
import com.wireguard.config.Interface
import com.wireguard.config.Peer
import com.wireguard.crypto.Key
import com.wireguard.crypto.KeyPair
import java.net.InetAddress

class OrbVpnService : VpnService() {
    private val TAG = "OrbVpnService"
    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    
    // WireGuard backend
    private var backend: GoBackend? = null
    private var tunnel: Tunnel? = null
    
    // Notification
    private val CHANNEL_ID = "OrbVPN_Channel"
    private val NOTIFICATION_ID = 1
    
    // Statistics
    private var bytesSent: Long = 0
    private var bytesReceived: Long = 0
    
    companion object {
        const val ACTION_CONNECT = "com.orbvpn.orbx.CONNECT"
        const val ACTION_DISCONNECT = "com.orbvpn.orbx.DISCONNECT"
        const val EXTRA_CONFIG = "config"
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "VPN Service created")
        createNotificationChannel()
        
        // Initialize WireGuard backend
        backend = GoBackend(applicationContext)
        Log.d(TAG, "✅ WireGuard backend initialized")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_CONNECT -> {
                @Suppress("UNCHECKED_CAST")
                val configData = intent.getSerializableExtra(EXTRA_CONFIG) as? HashMap<String, Any>
                if (configData != null) {
                    connect(configData)
                } else {
                    Log.e(TAG, "No config provided for connection")
                }
            }
            ACTION_DISCONNECT -> {
                disconnect()
            }
        }
        
        return START_STICKY
    }
    
    private fun connect(configData: Map<String, Any>) {
        if (isRunning) {
            Log.w(TAG, "VPN already running")
            return
        }
        
        try {
            Log.d(TAG, "🚀 Starting WireGuard VPN connection...")
            
            // Start foreground service with notification
            startForeground(NOTIFICATION_ID, createNotification("Connecting..."))
            
            // Extract WireGuard configuration from configData
            val privateKeyStr = configData["privateKey"] as? String 
                ?: throw Exception("Missing privateKey in config")
            val serverPublicKeyStr = configData["serverPublicKey"] as? String 
                ?: throw Exception("Missing serverPublicKey in config")
            val allocatedIp = configData["allocatedIp"] as? String 
                ?: throw Exception("Missing allocatedIp in config")
            val serverEndpoint = configData["serverEndpoint"] as? String 
                ?: throw Exception("Missing serverEndpoint in config")
            val mtu = (configData["mtu"] as? Number)?.toInt() ?: 1420
            
            @Suppress("UNCHECKED_CAST")
            val dnsList = configData["dns"] as? List<String> ?: listOf("1.1.1.1", "1.0.0.1")
            
            Log.d(TAG, "📝 Building WireGuard config:")
            Log.d(TAG, "   - Allocated IP: $allocatedIp")
            Log.d(TAG, "   - Server Endpoint: $serverEndpoint")
            Log.d(TAG, "   - MTU: $mtu")
            Log.d(TAG, "   - DNS: ${dnsList.joinToString(", ")}")
            
            // Build WireGuard Configuration
            val interfaceBuilder = Interface.Builder()
                .parsePrivateKey(privateKeyStr)
                .parseAddresses(allocatedIp)
                .parseDnsServers(dnsList.joinToString(","))
                .setMtu(mtu)
            
            val peerBuilder = Peer.Builder()
                .parsePublicKey(serverPublicKeyStr)
                .parseEndpoint(serverEndpoint)
                .parseAllowedIPs("0.0.0.0/0, ::/0")
                .setPersistentKeepalive(25)
            
            val config = Config.Builder()
                .setInterface(interfaceBuilder.build())
                .addPeer(peerBuilder.build())
                .build()
            
            Log.d(TAG, "✅ WireGuard config built successfully")
            
            // Create tunnel
            tunnel = object : Tunnel {
                override fun getName(): String = "OrbVPN"
                override fun onStateChange(newState: Tunnel.State) {
                    Log.d(TAG, "🔄 Tunnel state changed: $newState")
                    when (newState) {
                        Tunnel.State.UP -> {
                            isRunning = true
                            updateNotification("Connected")
                            Log.d(TAG, "✅ VPN tunnel is UP")
                        }
                        Tunnel.State.DOWN -> {
                            isRunning = false
                            updateNotification("Disconnected")
                            Log.d(TAG, "⛔ VPN tunnel is DOWN")
                        }
                        Tunnel.State.TOGGLE -> {
                            // Toggle state - do nothing, backend will handle
                            Log.d(TAG, "🔄 Tunnel toggling...")
                        }
                    }
                }
            }
            
            // Establish VPN tunnel using WireGuard backend
            Log.d(TAG, "🔌 Establishing VPN tunnel...")
            backend?.setState(tunnel, Tunnel.State.UP, config)
            
            Log.d(TAG, "╔════════════════════════════════════════╗")
            Log.d(TAG, "║   ✅ VPN Connected Successfully!      ║")
            Log.d(TAG, "╚════════════════════════════════════════╝")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ VPN connection failed", e)
            updateNotification("Connection failed: ${e.message}")
            stopSelf()
        }
    }
    
    private fun disconnect() {
        Log.d(TAG, "🔻 Disconnecting VPN...")
        
        isRunning = false
        
        try {
            if (tunnel != null && backend != null) {
                backend?.setState(tunnel, Tunnel.State.DOWN, null)
                Log.d(TAG, "✅ Tunnel brought down")
            }
            
            vpnInterface?.close()
            vpnInterface = null
            
        } catch (e: Exception) {
            Log.e(TAG, "Error during disconnect", e)
        }
        
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        
        Log.d(TAG, "✅ VPN disconnected")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OrbVPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Notification channel created")
        }
    }
    
    private fun createNotification(status: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OrbVPN")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(status: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, createNotification(status))
    }
    
    fun getStatistics(): Map<String, Long> {
        return mapOf(
            "bytesSent" to bytesSent,
            "bytesReceived" to bytesReceived
        )
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service being destroyed")
        
        // Force cleanup
        isRunning = false
        try {
            if (tunnel != null && backend != null) {
                backend?.setState(tunnel, Tunnel.State.DOWN, null)
            }
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error in onDestroy", e)
        }
        
        backend = null
        tunnel = null
        vpnInterface = null
        
        Log.d(TAG, "Service destroyed")
    }
    
    override fun onRevoke() {
        super.onRevoke()
        Log.w(TAG, "⚠️  VPN permission revoked by user")
        disconnect()
    }
}