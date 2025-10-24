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
import java.io.BufferedReader
import java.io.StringReader

class OrbVpnService : VpnService() {
    private val TAG = "OrbVpnService"
    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    
    // WireGuard backend
    private var backend: GoBackend? = null
    private var tunnel: OrbTunnel? = null
    
    // Notification
    private val CHANNEL_ID = "OrbVPN_Channel"
    private val NOTIFICATION_ID = 1
    
    // Inner class implementing Tunnel interface
    inner class OrbTunnel(private val name: String) : Tunnel {
        override fun getName(): String = name
        
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
                else -> {
                    Log.d(TAG, "🔄 Tunnel state: $newState")
                }
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "VPN Service created")
        createNotificationChannel()
        
        // Initialize WireGuard backend - CRITICAL: pass VpnService context
        try {
            backend = GoBackend(this)
            Log.d(TAG, "✅ WireGuard backend initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize WireGuard backend", e)
        }
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
            
            // Get the WireGuard config file
            val configFile = configData["configFile"] as? String 
                ?: throw Exception("Missing configFile in config")
            
            Log.d(TAG, "📝 Parsing WireGuard config...")
            
            // Parse WireGuard configuration
            val bufferedReader = BufferedReader(StringReader(configFile))
            val config = Config.parse(bufferedReader)
            
            Log.d(TAG, "✅ WireGuard config parsed successfully")
            Log.d(TAG, "   Interface: ${config.`interface`.addresses}")
            Log.d(TAG, "   DNS: ${config.`interface`.dnsServers}")
            Log.d(TAG, "   Peers: ${config.peers.size}")
            
            // Create tunnel
            tunnel = OrbTunnel("OrbVPN")
            
            // Use GoBackend to establish tunnel - this will internally call builder.establish()
            Log.d(TAG, "🔌 Establishing VPN tunnel via GoBackend...")
            backend?.setState(tunnel, Tunnel.State.UP, config)
            
            isRunning = true
            
            Log.d(TAG, "╔════════════════════════════════════════╗")
            Log.d(TAG, "║   ✅ VPN Connected Successfully!      ║")
            Log.d(TAG, "╚════════════════════════════════════════╝")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ VPN connection failed", e)
            Log.e(TAG, "   Exception type: ${e.javaClass.simpleName}")
            Log.e(TAG, "   Message: ${e.message}")
            e.printStackTrace()
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
    
    companion object {
        const val ACTION_CONNECT = "com.orbvpn.orbx.CONNECT"
        const val ACTION_DISCONNECT = "com.orbvpn.orbx.DISCONNECT"
        const val EXTRA_CONFIG = "config"
    }
}
