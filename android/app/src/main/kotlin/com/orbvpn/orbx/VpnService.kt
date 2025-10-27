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
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config

/**
 * OrbVPN Foreground Service
 * 
 * Manages WireGuard VPN tunnel lifecycle:
 * - Starts/stops WireGuard tunnel using GoBackend
 * - Shows foreground notification for Android requirements
 * - Broadcasts state changes to MainActivity via LocalBroadcastManager
 * 
 * ✅ FIXED: Properly handles disconnect and broadcasts all state changes
 */
class OrbVpnService : VpnService() {
    
    private val TAG = "OrbVpnService"
    
    // WireGuard components
    private var backend: GoBackend? = null
    private var tunnel: Tunnel? = null
    private var currentConfig: Map<String, Any>? = null
    
    // State tracking
    private var isRunning = false
    private var isConnecting = false
    
    // Handler for UI updates
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Notification constants
    private val CHANNEL_ID = "OrbVPN_Channel"
    private val NOTIFICATION_ID = 1
    
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
            Log.w(TAG, "⚠️  Service restarted with null intent")
            // Try to keep service alive if already running
            if (isRunning || isConnecting) {
                Log.d(TAG, "✅ Service already running or connecting, keeping alive")
            } else if (currentConfig != null) {
                Log.d(TAG, "🔄 Attempting to restore connection...")
                Thread {
                    connectWithConfig(currentConfig!!)
                }.start()
            } else {
                Log.w(TAG, "⚠️  No config and not running, stopping service")
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
                    broadcastStateChange("connecting")
                    Thread {
                        connectWithConfig(configData)
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
                Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                Log.d(TAG, "🔌 Disconnecting VPN...")
                Log.d(TAG, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                broadcastStateChange("disconnecting")
                disconnect()
            }
            
            else -> {
                Log.w(TAG, "⚠️  Unknown action: ${intent.action}")
                if (!isRunning && !isConnecting) {
                    stopSelf()
                }
            }
        }
        
        return START_STICKY
    }
    
    /**
     * Connect to WireGuard with given config
     */
    private fun connectWithConfig(configData: Map<String, Any>) {
        if (isRunning) {
            Log.w(TAG, "⚠️  VPN already running, disconnecting first...")
            disconnect()
            Thread.sleep(500)
        }
        
        try {
            mainHandler.post {
                updateNotification("Connecting...")
            }
            
            val configFile = configData["configFile"] as? String 
                ?: throw IllegalArgumentException("Config file is missing")
            
            // Save current config
            currentConfig = configData
            
            Log.d(TAG, "📝 Parsing WireGuard configuration...")
            
            // Parse WireGuard config
            val config = Config.parse(configFile.byteInputStream())
            
            Log.d(TAG, "✅ WireGuard config parsed successfully")
            Log.d(TAG, "   Interface addresses: ${config.`interface`.addresses}")
            Log.d(TAG, "   DNS servers: ${config.`interface`.dnsServers}")
            Log.d(TAG, "   Number of peers: ${config.peers.size}")
            
            // Create tunnel object
            tunnel = object : Tunnel {
                override fun getName(): String = "OrbVPN"
                override fun onStateChange(newState: Tunnel.State) {
                    Log.d(TAG, "🔄 Tunnel state changed: $newState")
                    handleStateChange(newState)
                }
            }
            
            // Start tunnel using GoBackend
            Log.d(TAG, "🔧 Starting WireGuard tunnel with GoBackend...")
            Log.d(TAG, "✅ GoBackend.setState() called, waiting for tunnel state change...")
            backend?.setState(tunnel!!, Tunnel.State.UP, config)
            
            // State change will be handled in onStateChange callback
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Connection failed", e)
            Log.e(TAG, "Exception type: ${e.javaClass.simpleName}")
            Log.e(TAG, "Error message: ${e.message}")
            e.printStackTrace()
            
            isConnecting = false
            isRunning = false
            
            mainHandler.post {
                updateNotification("Connection failed")
            }
            
            broadcastStateChange("error")
            stopSelf()
        }
    }
    
    /**
     * ✅ FIXED: Proper disconnect implementation
     */
    private fun disconnect() {
        Log.d(TAG, "🔌 Disconnecting VPN...")
        
        try {
            if (tunnel != null && backend != null) {
                Log.d(TAG, "🔻 Bringing tunnel DOWN...")
                backend?.setState(tunnel, Tunnel.State.DOWN, null)
                // State change will be handled in onStateChange callback
            } else {
                Log.w(TAG, "⚠️  No active tunnel to disconnect")
                isRunning = false
                isConnecting = false
                broadcastStateChange("disconnected")
                stopForeground(true)
                stopSelf()
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error during disconnect", e)
            isRunning = false
            isConnecting = false
            broadcastStateChange("disconnected")
            stopForeground(true)
            stopSelf()
        }
    }
    
    /**
     * Handle state changes from WireGuard GoBackend
     */
    private fun handleStateChange(newState: Tunnel.State) {
        when (newState) {
            Tunnel.State.UP -> {
                isRunning = true
                isConnecting = false
                mainHandler.post {
                    updateNotification("Connected")
                }
                
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
                mainHandler.post {
                    updateNotification("Disconnected")
                }
                
                Log.d(TAG, "⛔ VPN tunnel is DOWN")
                
                // CRITICAL: Broadcast state change to MainActivity
                broadcastStateChange("disconnected")
                
                // Stop the service
                stopForeground(true)
                stopSelf()
            }
            
            else -> {
                Log.d(TAG, "🔄 Tunnel state: $newState")
            }
        }
    }
    
    /**
     * ✅ CRITICAL: Broadcast state change to MainActivity via LocalBroadcastManager
     */
    private fun broadcastStateChange(state: String) {
        Log.d(TAG, "📡 Broadcasting state change: $state")
        val intent = Intent(ACTION_VPN_STATE_CHANGED).apply {
            putExtra(EXTRA_VPN_STATE, state)
        }
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }
    
    /**
     * Create notification channel for Android O+
     */
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
    
    /**
     * Create foreground service notification
     */
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
    
    /**
     * Update notification text
     */
    private fun updateNotification(status: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, createNotification(status))
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🔴 Service being destroyed")
        
        isRunning = false
        isConnecting = false
        
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