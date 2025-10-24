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
import com.wireguard.config.Interface
import com.wireguard.config.InetNetwork
import com.wireguard.config.Peer
import kotlinx.coroutines.*
import java.net.InetAddress

class OrbVpnService : VpnService() {
    private val TAG = "OrbVpnService"
    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // WireGuard backend
    private var backend: GoBackend? = null
    private var tunnel: Tunnel? = null
    
    // Notification
    private val CHANNEL_ID = "OrbVPN_Channel"
    private val NOTIFICATION_ID = 1
    
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
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getSerializableExtra(EXTRA_CONFIG) as? HashMap<String, Any>
                if (config != null) {
                    connect(config)
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
    
    private fun connect(config: Map<String, Any>) {
        if (isRunning) {
            Log.w(TAG, "VPN already running")
            return
        }
        
        scope.launch {
            try {
                Log.d(TAG, "Starting VPN connection...")
                
                // Start foreground service with notification
                startForeground(NOTIFICATION_ID, createNotification("Connecting..."))
                
                // Start WireGuard tunnel (it will create VPN interface internally)
                startWireGuardTunnel(config)
                
                isRunning = true
                updateNotification("Connected")
                Log.d(TAG, "✅ VPN connected successfully")
                
            } catch (e: Exception) {
                Log.e(TAG, "VPN connection failed", e)
                updateNotification("Connection failed: ${e.message}")
                stopSelf()
            }
        }
    }
    
    private suspend fun startWireGuardTunnel(config: Map<String, Any>) = withContext(Dispatchers.IO) {
        try {
            // Extract config
            val privateKey = config["privateKey"] as String
            val serverPublicKey = config["serverPublicKey"] as String  
            val endpoint = config["endpoint"] as String
            val allocatedIp = config["allocatedIp"] as String
            val dns = (config["dns"] as? List<String>) ?: listOf("1.1.1.1", "8.8.8.8")
            val mtu = (config["mtu"] as? Int) ?: 1400
            
            Log.d(TAG, "Building WireGuard config...")
            Log.d(TAG, "  Endpoint: $endpoint")
            Log.d(TAG, "  Allocated IP: $allocatedIp")
            Log.d(TAG, "  DNS: ${dns.joinToString(", ")}")
            
            // Build WireGuard configuration
            val interfaceBuilder = Interface.Builder()
                .parsePrivateKey(privateKey)
                .addAddress(InetNetwork.parse("$allocatedIp/24"))
            
            // Add DNS servers (parse as InetAddress)
            dns.forEach { dnsServer ->
                try {
                    interfaceBuilder.addDnsServer(InetAddress.getByName(dnsServer))
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to parse DNS server: $dnsServer", e)
                }
            }
            
            val wgConfig = Config.Builder()
                .setInterface(interfaceBuilder.build())
                .addPeer(Peer.Builder()
                    .parsePublicKey(serverPublicKey)
                    .parseEndpoint(endpoint)
                    .addAllowedIp(InetNetwork.parse("0.0.0.0/0"))
                    .addAllowedIp(InetNetwork.parse("::/0"))
                    .setPersistentKeepalive(25)
                    .build())
                .build()
            
            // Create tunnel object
            tunnel = object : Tunnel {
                override fun getName() = "wg0"
                
                override fun onStateChange(newState: Tunnel.State) {
                    Log.d(TAG, "Tunnel state changed: $newState")
                    when (newState) {
                        Tunnel.State.UP -> {
                            Log.d(TAG, "✅ WireGuard tunnel UP")
                        }
                        Tunnel.State.DOWN -> {
                            Log.d(TAG, "❌ WireGuard tunnel DOWN")
                        }
                        Tunnel.State.TOGGLE -> {
                            Log.d(TAG, "🔄 WireGuard tunnel TOGGLE")
                        }
                    }
                }
            }
            
            // Start the tunnel (GoBackend will create VPN interface internally)
            Log.d(TAG, "Starting WireGuard tunnel...")
            backend?.setState(tunnel!!, Tunnel.State.UP, wgConfig)
            
            Log.d(TAG, "✅ WireGuard tunnel started successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start WireGuard tunnel", e)
            throw e
        }
    }
    
private fun disconnect() {
    Log.d(TAG, "Disconnecting VPN...")
    
    isRunning = false
    
    scope.launch {
        try {
            // Stop WireGuard tunnel first
            if (tunnel != null && backend != null) {
                Log.d(TAG, "Stopping WireGuard tunnel...")
                backend?.setState(tunnel, Tunnel.State.DOWN, null)
                tunnel = null
            }
            
            // Give WireGuard time to clean up
            delay(500)
            
            // Close VPN interface
            vpnInterface?.close()
            vpnInterface = null
            
            // Shutdown backend
            backend = null
            
        } catch (e: Exception) {
            Log.e(TAG, "Error during disconnect", e)
        }
        
        withContext(Dispatchers.Main) {
            scope.cancel()
            stopForeground(true)
            stopSelf()
        }
        
        Log.d(TAG, "✅ VPN disconnected completely")
    }
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
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OrbVPN Connection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows VPN connection status"
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(text: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OrbVPN")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(text: String) {
        val notification = createNotification(text)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        disconnect()
        backend = null
        Log.d(TAG, "Service destroyed")
    }
}