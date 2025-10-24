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
    
    // Store current config for potential reconnection
    private var currentConfig: Config? = null
    
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
        Log.d(TAG, "🎬 VPN Service created")
        createNotificationChannel()
        
        // Initialize WireGuard backend with VpnService context
        try {
            backend = GoBackend(applicationContext)
            Log.d(TAG, "✅ WireGuard backend initialized")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize WireGuard backend", e)
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "📨 onStartCommand: ${intent?.action}")
        
        // Handle null intent (service restart)
        if (intent == null) {
            Log.w(TAG, "⚠️ Service restarted with null intent")
            // Try to reconnect if we have a saved config
            if (currentConfig != null && !isRunning) {
                Log.d(TAG, "🔄 Attempting to restore connection...")
                connectWithConfig(currentConfig!!)
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
                    connect(configData)
                } else {
                    Log.e(TAG, "❌ No config provided for connection")
                    stopSelf()
                }
            }
            ACTION_DISCONNECT -> {
                disconnect()
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action: ${intent.action}")
            }
        }
        
        return START_STICKY
    }
    
    private fun connect(configData: Map<String, Any>) {
        if (isRunning) {
            Log.w(TAG, "⚠️ VPN already running, disconnecting first...")
            disconnect()
            // Wait a bit for cleanup
            Thread.sleep(500)
        }
        
        try {
            // Start foreground service with notification FIRST
            Log.d(TAG, "✅ Foreground service started")
            startForeground(NOTIFICATION_ID, createNotification("Connecting..."))
            
            // Get the WireGuard config file
            val configFile = configData["configFile"] as? String 
                ?: throw Exception("❌ Missing configFile in config")
            
            Log.d(TAG, "📝 Parsing WireGuard configuration...")
            
            // Parse WireGuard configuration
            val bufferedReader = BufferedReader(StringReader(configFile))
            val config = Config.parse(bufferedReader)
            
            // Save config for potential reconnection
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
            Log.e(TAG, "Stack trace:")
            e.printStackTrace()
            
            updateNotification("Connection Failed")
            isRunning = false
            
            // Stop service on failure
            stopSelf()
        }
    }
    
    private fun connectWithConfig(config: Config) {
        try {
            Log.d(TAG, "🔧 Creating VPN interface with Builder...")
            
            // Build VPN interface using VpnService.Builder
            val builder = Builder()
            
            // Set session name
            builder.setSession("OrbVPN")
            Log.d(TAG, "   ✓ Session name set")
            
            // Add interface addresses
            for (addr in config.`interface`.addresses) {
                builder.addAddress(addr.address, addr.mask)
                Log.d(TAG, "   ✓ Address added: ${addr.address}/${addr.mask}")
            }
            
            // Add DNS servers
            for (dns in config.`interface`.dnsServers) {
                builder.addDnsServer(dns)
                Log.d(TAG, "   ✓ DNS added: $dns")
            }
            
            // Add routes for each peer
            for (peer in config.peers) {
                for (allowedIp in peer.allowedIps) {
                    builder.addRoute(allowedIp.address, allowedIp.mask)
                    Log.d(TAG, "   ✓ Route added: ${allowedIp.address}/${allowedIp.mask}")
                }
            }
            
            // Set MTU if specified
            val mtu = config.`interface`.mtu
            if (mtu.isPresent && mtu.get() > 0) {
                builder.setMtu(mtu.get())
                Log.d(TAG, "   ✓ MTU set: ${mtu.get()}")
            }
            
            // Set blocking mode to false for better performance
            builder.setBlocking(false)
            Log.d(TAG, "   ✓ Non-blocking mode enabled")
            
            // CRITICAL: Establish the VPN interface
            Log.d(TAG, "🔌 Establishing VPN interface...")
            
            // Close any existing interface first
            vpnInterface?.close()
            vpnInterface = null
            
            // Establish new interface
            vpnInterface = builder.establish()
            
            if (vpnInterface == null) {
                throw Exception("❌ Failed to establish VPN interface - Builder.establish() returned null")
            }
            
            Log.d(TAG, "✅ VPN interface established (fd: ${vpnInterface!!.fd})")
            
            // Create tunnel
            if (tunnel == null) {
                tunnel = OrbTunnel("OrbVPN")
            }
            
            // Use GoBackend to manage the tunnel with our established interface
            Log.d(TAG, "🚀 Starting WireGuard tunnel with GoBackend...")
            backend?.setState(tunnel, Tunnel.State.UP, config)
            
            isRunning = true
            
            Log.d(TAG, "╔════════════════════════════════════════╗")
            Log.d(TAG, "║   ✅ VPN Connected Successfully!       ║")
            Log.d(TAG, "╚════════════════════════════════════════╝")
            
            updateNotification("Connected")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to establish VPN connection", e)
            throw e
        }
    }
    
    private fun disconnect() {
        Log.d(TAG, "🔌 Disconnecting VPN...")
        
        try {
            // Stop WireGuard tunnel
            if (tunnel != null && backend != null) {
                backend?.setState(tunnel, Tunnel.State.DOWN, null)
            }
            
            // Close VPN interface
            vpnInterface?.close()
            vpnInterface = null
            
            isRunning = false
            
            Log.d(TAG, "✅ VPN disconnected")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error during disconnect", e)
        } finally {
            // Always stop foreground and service
            stopForeground(true)
            stopSelf()
        }
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
        
        // Force cleanup
        isRunning = false
        try {
            if (tunnel != null && backend != null) {
                backend?.setState(tunnel, Tunnel.State.DOWN, null)
            }
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in onDestroy", e)
        }
        
        backend = null
        tunnel = null
        vpnInterface = null
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
    }
}