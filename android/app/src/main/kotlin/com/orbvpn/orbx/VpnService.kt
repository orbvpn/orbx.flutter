package com.orbvpn.orbx

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.io.BufferedReader
import java.io.StringReader
import kotlinx.coroutines.*


class OrbVpnService : VpnService() {
    private val TAG = "OrbVpnService"
    private var isRunning = false
    private var isConnecting = false
    
    // WireGuard backend
    private var backend: GoBackend? = null
    private var tunnel: OrbTunnel? = null
    
    // Store current config
    private var currentConfig: Config? = null
    
    // Handler for main thread operations
    private val mainHandler = Handler(Looper.getMainLooper())
    
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
                    isConnecting = false
                    updateNotification("Connected")
                    Log.d(TAG, "✅ VPN tunnel is UP")
                    Log.d(TAG, "╔════════════════════════════════════════╗")
                    Log.d(TAG, "║   ✅ VPN Connected Successfully!       ║")
                    Log.d(TAG, "╚════════════════════════════════════════╝")
                    
                    // CRITICAL: Broadcast state change to MainActivity
                    broadcastStateChange("connected")
                }
                Tunnel.State.DOWN -> {
                    isRunning = false
                    isConnecting = false
                    updateNotification("Disconnected")
                    Log.d(TAG, "⛔ VPN tunnel is DOWN")
                    
                    // CRITICAL: Broadcast state change to MainActivity
                    broadcastStateChange("disconnected")
                }
                else -> {
                    Log.d(TAG, "🔄 Tunnel state: $newState")
                }
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🎬 VPN Service created")
        createNotificationChannel()
        
        // Initialize WireGuard backend
        try {
            backend = GoBackend(applicationContext)
            Log.d(TAG, "✅ WireGuard backend initialized")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize WireGuard backend", e)
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "📨 onStartCommand: ${intent?.action}")
        
        // CRITICAL: Start foreground immediately to avoid crash
        startForeground(NOTIFICATION_ID, createNotification("Starting..."))
        
        if (intent == null) {
            Log.w(TAG, "⚠️ Service restarted with null intent")
            if (currentConfig != null && !isRunning && !isConnecting) {
                Log.d(TAG, "🔄 Attempting to restore connection...")
                Thread {
                    connectWithConfig(currentConfig!!)
                }.start()
            } else if (isRunning || isConnecting) {
                Log.d(TAG, "✅ Service already running or connecting, keeping alive")
            } else {
                Log.w(TAG, "⚠️ No config and not running/connecting, stopping")
                stopSelf()
            }
            return START_STICKY
        }
        
        when (intent.action) {
            ACTION_CONNECT -> {
                Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                Log.d(TAG, "🚀 Starting WireGuard VPN connection...")
                Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                
                @Suppress("UNCHECKED_CAST")
                val configData = intent.getSerializableExtra(EXTRA_CONFIG) as? HashMap<String, Any>
                
                if (configData != null) {
                    isConnecting = true
                    Thread {
                        connect(configData)
                    }.start()
                } else {
                    Log.e(TAG, "❌ No config provided for connection")
                    if (!isRunning && !isConnecting) {
                        stopSelf()
                    } else {
                        Log.d(TAG, "✅ Already connected or connecting, ignoring empty config")
                    }
                }
            }
            ACTION_DISCONNECT -> {
                disconnect()
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action: ${intent.action}")
                if (!isRunning && !isConnecting) {
                    stopSelf()
                }
            }
        }
        
        return START_STICKY
    }
    
    private fun connect(configData: Map<String, Any>) {
        if (isRunning) {
            Log.w(TAG, "⚠️ VPN already running, disconnecting first...")
            disconnect()
            Thread.sleep(500)
        }
        
        try {
            mainHandler.post {
                updateNotification("Connecting...")
            }
            
            val configFile = configData["configFile"] as? String 
                ?: throw Exception("❌ Missing configFile in config")
            
            Log.d(TAG, "📝 Parsing WireGuard configuration...")
            
            val config = Config.parse(BufferedReader(StringReader(configFile)))
            currentConfig = config
            
            Log.d(TAG, "✅ WireGuard config parsed successfully")
            Log.d(TAG, "   Interface addresses: ${config.`interface`.addresses}")
            Log.d(TAG, "   DNS servers: ${config.`interface`.dnsServers}")
            Log.d(TAG, "   Number of peers: ${config.peers.size}")
            
            connectWithConfig(config)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ VPN connection failed", e)
            Log.e(TAG, "Error type: ${e.javaClass.simpleName}")
            Log.e(TAG, "Error message: ${e.message}")
            e.printStackTrace()
            
            isConnecting = false
            
            mainHandler.post {
                updateNotification("Connection Failed")
                isRunning = false
                broadcastStateChange("error")
                stopSelf()
            }
        }
    }
    
    private fun connectWithConfig(config: Config) {
        try {
            Log.d(TAG, "🔧 Starting WireGuard tunnel with GoBackend...")
            
            if (tunnel == null) {
                tunnel = OrbTunnel("OrbVPN")
            }
            
            backend?.setState(tunnel, Tunnel.State.UP, config)
            
            Log.d(TAG, "✅ GoBackend.setState() called, waiting for tunnel state change...")
            
            mainHandler.post {
                updateNotification("Connecting...")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to establish VPN connection", e)
            Log.e(TAG, "Error type: ${e.javaClass.simpleName}")
            Log.e(TAG, "Error message: ${e.message}")
            e.printStackTrace()
            throw e
        }
    }
    
    private fun disconnect() {
        Log.d(TAG, "🔌 Disconnecting VPN...")
        
        try {
            if (tunnel != null && backend != null) {
                backend?.setState(tunnel, Tunnel.State.DOWN, null)
            }
            
            isRunning = false
            Log.d(TAG, "✅ VPN disconnected")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error during disconnect", e)
        } finally {
            stopForeground(true)
            stopSelf()
        }
    }
    
    /**
     * Broadcast state change to MainActivity via LocalBroadcastManager
     */
    private fun broadcastStateChange(state: String) {
        Log.d(TAG, "📡 Broadcasting state change: $state")
        val intent = Intent(ACTION_VPN_STATE_CHANGED).apply {
            putExtra(EXTRA_VPN_STATE, state)
        }
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OrbVPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows VPN connection status"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
            
            Log.d(TAG, "✅ Notification channel created")
        }
    }
    
    private fun createNotification(status: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OrbVPN")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    private fun updateNotification(status: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, createNotification(status))
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🔴 Service being destroyed")
        
        isRunning = false
        try {
            if (tunnel != null && backend != null) {
                backend?.setState(tunnel, Tunnel.State.DOWN, null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in onDestroy", e)
        }
        
        backend = null
        tunnel = null
        currentConfig = null
        
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
        
        // Broadcast action for state changes
        const val ACTION_VPN_STATE_CHANGED = "com.orbvpn.orbx.VPN_STATE_CHANGED"
        const val EXTRA_VPN_STATE = "vpn_state"
    }
}