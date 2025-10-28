package com.orbvpn.orbx

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import kotlinx.coroutines.*
import java.io.StringReader

/**
 * OrbVpnService - Android VPN Service with HTTP Tunnel Integration
 * 
 * This service implements Option 1: Client-Side Packet Tunneling
 * 
 * Architecture:
 * 1. Create WireGuard TUN interface
 * 2. Intercept packets from TUN interface
 * 3. Send packets via HTTPS (protocol mimicry)
 * 4. Receive response packets
 * 5. Write packets back to TUN interface
 */
class OrbVpnService : VpnService() {
    
    private val TAG = "OrbVpnService"
    
    companion object {
        const val ACTION_CONNECT = "com.orbvpn.orbx.ACTION_CONNECT"
        const val ACTION_DISCONNECT = "com.orbvpn.orbx.ACTION_DISCONNECT"
        const val EXTRA_CONFIG = "config"
        const val ACTION_VPN_STATE_CHANGED = "com.orbvpn.orbx.VPN_STATE_CHANGED"
        const val EXTRA_VPN_STATE = "state"
        
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "OrbVPN_Channel"
    }
    
    // WireGuard backend
    private var backend: GoBackend? = null
    private var tunnel: Tunnel? = null
    
    // TUN interface
    private var tunInterface: ParcelFileDescriptor? = null
    
    // HTTP Tunnel components
    private var httpTunnelHandler: HttpTunnelHandler? = null
    private var packetInterceptor: TunPacketInterceptor? = null
    
    // Coroutine scope
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    
    // Service state
    @Volatile
    private var isRunning = false
    
    @Volatile
    private var isConnecting = false
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🚀 OrbVpnService created")
        
        createNotificationChannel()
        
        // Initialize WireGuard backend
        backend = GoBackend(applicationContext)
        Log.d(TAG, "✅ WireGuard backend initialized")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "📥 Service command received")
        Log.d(TAG, "   Action: ${intent?.action}")
        Log.d(TAG, "═══════════════════════════════════════")
        
        // Start foreground service immediately
        startForeground(NOTIFICATION_ID, createNotification("Starting..."))
        
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getSerializableExtra(EXTRA_CONFIG) as? HashMap<String, Any>
                if (config != null) {
                    handleConnect(config)
                } else {
                    Log.e(TAG, "❌ No configuration provided")
                    stopSelf()
                }
            }
            
            ACTION_DISCONNECT -> {
                handleDisconnect()
            }
            
            else -> {
                Log.w(TAG, "⚠️  Unknown action: ${intent?.action}")
                stopSelf()
            }
        }
        
        return START_STICKY
    }
    
    /**
     * Handle VPN connection
     */
    private fun handleConnect(config: HashMap<String, Any>) {
        Log.d(TAG, "🔌 Handling VPN connection...")
        
        if (isConnecting || isRunning) {
            Log.w(TAG, "⚠️  Already connecting or connected")
            return
        }
        
        isConnecting = true
        updateNotification("Connecting...")
        broadcastStateChange("connecting")
        
        scope.launch {
            try {
                Log.d(TAG, "📋 Configuration received:")
                Log.d(TAG, "   Server: ${config["serverEndpoint"]}")
                Log.d(TAG, "   Protocol: ${config["protocol"]}")
                Log.d(TAG, "   Allocated IP: ${config["allocatedIp"]}")
                
                // Build WireGuard config
                val wgConfig = buildWireGuardConfig(config)
                
                // Parse config
                val configText = wgConfig.toWgQuickString()
                Log.d(TAG, "📝 WireGuard config built:")
                Log.d(TAG, configText)
                
                val parsedConfig = Config.parse(StringReader(configText))
                
                // Create TUN interface using Builder
                tunInterface = createTunInterface(config)
                
                if (tunInterface == null) {
                    throw Exception("Failed to create TUN interface")
                }
                
                Log.d(TAG, "✅ TUN interface created")
                
                // CRITICAL: Start HTTP tunnel BEFORE WireGuard
                startHttpTunnel(config)
                
                // Start WireGuard tunnel
                startWireGuardTunnel(parsedConfig)
                
                // CRITICAL: Start packet interceptor to route packets through HTTP
                startPacketInterceptor()
                
                isRunning = true
                isConnecting = false
                updateNotification("Connected")
                broadcastStateChange("connected")
                
                Log.d(TAG, "╔════════════════════════════════════════╗")
                Log.d(TAG, "║   ✅ VPN Connection Established!       ║")
                Log.d(TAG, "║   🎭 Traffic disguised as ${config["protocol"]} ║")
                Log.d(TAG, "╚════════════════════════════════════════╝")
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Connection failed", e)
                isConnecting = false
                updateNotification("Connection failed")
                broadcastStateChange("error")
                stopSelf()
            }
        }
    }
    
    /**
     * Build WireGuard configuration
     */
    private fun buildWireGuardConfig(config: HashMap<String, Any>): Config {
        val privateKey = config["privateKey"] as String
        val allocatedIp = config["allocatedIp"] as String
        val dns = config["dns"] as List<String>
        val mtu = config["mtu"] as Int
        val serverPublicKey = config["serverPublicKey"] as String
        val serverEndpoint = config["serverEndpoint"] as String
        
        return Config.Builder()
            .setInterface(com.wireguard.config.Interface.Builder()
                .parsePrivateKey(privateKey)
                .parseAddresses(allocatedIp)
                .parseDnsServers(dns.joinToString(", "))
                .setMtu(mtu)
                .build())
            .addPeer(com.wireguard.config.Peer.Builder()
                .parsePublicKey(serverPublicKey)
                .parseEndpoint(serverEndpoint)
                .parseAllowedIPs("0.0.0.0/0, ::/0")
                .build())
            .build()
    }
    
    /**
     * Create TUN interface using VpnService.Builder
     */
    private fun createTunInterface(config: HashMap<String, Any>): ParcelFileDescriptor? {
        Log.d(TAG, "🔧 Creating TUN interface...")
        
        val allocatedIp = config["allocatedIp"] as String
        val dns = config["dns"] as List<String>
        val mtu = config["mtu"] as Int
        
        val builder = Builder()
            .setSession("OrbVPN")
            .setMtu(mtu)
            .addAddress(allocatedIp, 24)
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .setBlocking(false)
        
        // Add DNS servers
        dns.forEach { builder.addDnsServer(it) }
        
        // Allow bypass for our own app
        builder.addDisallowedApplication(packageName)
        
        return builder.establish()
    }
    
    /**
     * Start HTTP tunnel for protocol mimicry
     */
    private fun startHttpTunnel(config: HashMap<String, Any>) {
        Log.d(TAG, "🎭 Starting HTTP tunnel...")
        
        val serverAddress = (config["serverEndpoint"] as String).split(":")[0]
        val authToken = config["authToken"] as String
        val protocol = config["protocol"] as String
        
        httpTunnelHandler = HttpTunnelHandler(
            serverAddress = serverAddress,
            authToken = authToken,
            protocol = protocol,
            context = applicationContext
        )
        
        Log.d(TAG, "✅ HTTP tunnel handler created")
    }
    
    /**
     * Start WireGuard tunnel
     */
    private fun startWireGuardTunnel(config: Config) {
        Log.d(TAG, "🔐 Starting WireGuard tunnel...")
        
        tunnel = object : Tunnel {
            override fun getName(): String = "OrbVPN"
            
            override fun onStateChange(newState: Tunnel.State) {
                Log.d(TAG, "🔄 WireGuard state changed: $newState")
            }
        }
        
        backend?.setState(tunnel!!, Tunnel.State.UP, config)
        
        Log.d(TAG, "✅ WireGuard tunnel started")
    }
    
    /**
     * Start packet interceptor
     */
    private fun startPacketInterceptor() {
        Log.d(TAG, "📦 Starting packet interceptor...")
        
        if (tunInterface == null || httpTunnelHandler == null) {
            throw Exception("TUN interface or HTTP tunnel not initialized")
        }
        
        packetInterceptor = TunPacketInterceptor(
            tunInterface = tunInterface!!,
            httpTunnelHandler = httpTunnelHandler!!,
            scope = scope
        )
        
        packetInterceptor?.start()
        
        Log.d(TAG, "✅ Packet interceptor started")
    }
    
    /**
     * Handle VPN disconnection
     */
    private fun handleDisconnect() {
        Log.d(TAG, "🔌 Handling VPN disconnection...")
        
        isRunning = false
        updateNotification("Disconnecting...")
        broadcastStateChange("disconnecting")
        
        // Stop packet interceptor
        packetInterceptor?.stop()
        packetInterceptor = null
        
        // Stop HTTP tunnel
        httpTunnelHandler?.stop()
        httpTunnelHandler = null
        
        // Stop WireGuard
        tunnel?.let {
            backend?.setState(it, Tunnel.State.DOWN, null)
        }
        tunnel = null
        
        // Close TUN interface
        tunInterface?.close()
        tunInterface = null
        
        updateNotification("Disconnected")
        broadcastStateChange("disconnected")
        
        Log.d(TAG, "✅ VPN disconnected")
        
        stopForeground(true)
        stopSelf()
    }
    
    /**
     * Broadcast state change to MainActivity
     */
    private fun broadcastStateChange(state: String) {
        Log.d(TAG, "📡 Broadcasting state change: $state")
        val intent = Intent(ACTION_VPN_STATE_CHANGED).apply {
            putExtra(EXTRA_VPN_STATE, state)
        }
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }
    
    /**
     * Create notification channel
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
        }
    }
    
    /**
     * Create notification
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
     * Update notification
     */
    private fun updateNotification(status: String) {
        val notification = createNotification(status)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🛑 OrbVpnService destroyed")
        
        isRunning = false
        
        // Cleanup
        packetInterceptor?.stop()
        httpTunnelHandler?.stop()
        tunInterface?.close()
        scope.cancel()
        
        Log.d(TAG, "✅ Cleanup complete")
    }
}