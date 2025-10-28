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
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.Socket
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLHandshakeException
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import java.security.cert.X509Certificate
import java.io.IOException
  import kotlinx.coroutines.delay

class OrbVpnService : VpnService() {
    
    companion object {
        private const val TAG = "OrbVpnService"
        private const val CHANNEL_ID = "orbvpn_channel"
        private const val NOTIFICATION_ID = 1
        
        const val ACTION_CONNECT = "com.orbvpn.orbx.ACTION_CONNECT"
        const val ACTION_DISCONNECT = "com.orbvpn.orbx.ACTION_DISCONNECT"
        const val EXTRA_CONFIG = "config"
        
        const val BROADCAST_STATE_CHANGED = "com.orbvpn.orbx.STATE_CHANGED"
        const val BROADCAST_ERROR = "com.orbvpn.orbx.ERROR"
        const val EXTRA_STATE = "state"
        const val EXTRA_ERROR_MESSAGE = "error_message"
        
        const val STATE_CONNECTING = "connecting"
        const val STATE_CONNECTED = "connected"
        const val STATE_DISCONNECTING = "disconnecting"
        const val STATE_DISCONNECTED = "disconnected"
    }
    
    private var vpnInterface: ParcelFileDescriptor? = null
    private var backend: GoBackend? = null
    private var currentConfig: Config? = null
    private val serviceJob = Job()
    private val serviceScope = CoroutineScope(Dispatchers.IO + serviceJob)
    
    private var httpTunnelSocket: Socket? = null
    private var httpTunnelJob: Job? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🔵 Service created")
        createNotificationChannel()
        backend = GoBackend(applicationContext)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "🔵 onStartCommand: action=${intent?.action}")
        
        when (intent?.action) {
            ACTION_CONNECT -> {
                val configMap = intent.getSerializableExtra(EXTRA_CONFIG) as? HashMap<String, Any>
                Log.d(TAG, "🔵 Received connect request")
                Log.d(TAG, "   Config map: $configMap")
                
                if (configMap != null) {
                    startForeground(NOTIFICATION_ID, createNotification("Connecting..."))
                    connectVpn(configMap)
                } else {
                    Log.e(TAG, "❌ Config map is null")
                    broadcastError("Configuration is missing")
                    stopSelf()
                }
            }
            ACTION_DISCONNECT -> {
                Log.d(TAG, "🔵 Received disconnect request")
                disconnectVpn()
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action: ${intent?.action}")
            }
        }
        
        return START_NOT_STICKY
    }

private fun connectVpn(config: HashMap<String, Any>) {
    serviceScope.launch {
        try {
            Log.d(TAG, "🔵 Starting VPN connection")
            broadcastStateChange(STATE_CONNECTING)
            
            // Extract configuration with proper casting from Any
            val privateKey = config["privateKey"] as? String ?: run {
                Log.e(TAG, "❌ Missing privateKey")
                broadcastError("Missing private key")
                return@launch
            }
            
            val serverEndpoint = config["serverEndpoint"] as? String ?: run {
                Log.e(TAG, "❌ Missing serverEndpoint")
                broadcastError("Missing server endpoint")
                return@launch
            }
            
            val serverPublicKey = config["serverPublicKey"] as? String ?: run {
                Log.e(TAG, "❌ Missing serverPublicKey")
                broadcastError("Missing server public key")
                return@launch
            }
            
            val allowedIPs = config["allowedIPs"] as? String ?: "0.0.0.0/0"
            
            // ✅ Handle DNS as ArrayList or String
            val dns = when (val dnsValue = config["dns"]) {
                is String -> dnsValue
                is ArrayList<*> -> dnsValue.joinToString(", ")
                else -> "1.1.1.1"
            }
            
            val mtu = (config["mtu"] as? String)?.toIntOrNull() ?: 1420
            
            // ✅ Handle missing protocol and authToken with defaults
            val protocol = config["protocol"] as? String ?: "http"
            val authToken = config["authToken"] as? String ?: ""
            
            Log.d(TAG, "🔵 Configuration extracted:")
            Log.d(TAG, "   Server: $serverEndpoint")
            Log.d(TAG, "   AllowedIPs: $allowedIPs")
            Log.d(TAG, "   DNS: $dns")
            Log.d(TAG, "   MTU: $mtu")
            Log.d(TAG, "   Protocol: $protocol")
            Log.d(TAG, "   AuthToken: ${if (authToken.isNotEmpty()) "present" else "empty"}")
            
            // Start HTTP tunnel if protocol is specified
            if (protocol.isNotEmpty()) {
                startHttpTunnel(protocol, serverEndpoint, authToken)
            }
            
            // ✅ Extract allocatedIp from config
            val allocatedIp = config["allocatedIp"] as? String ?: "10.8.0.2"

            val wgConfig = buildWireGuardConfig(
                privateKey = privateKey,
                serverEndpoint = serverEndpoint,
                serverPublicKey = serverPublicKey,
                allowedIPs = allowedIPs,
                dns = dns,
                mtu = mtu,
                allocatedIp = allocatedIp  // ✅ PASS IT HERE
            )
            
            currentConfig = wgConfig
            
            // Establish VPN
            Log.d(TAG, "🔵 Establishing VPN tunnel...")
            val tunnel = object : Tunnel {
                override fun getName(): String = "OrbVPN"
                override fun onStateChange(newState: Tunnel.State) {
                    Log.d(TAG, "🔵 Tunnel state changed: $newState")
                    when (newState) {
                        Tunnel.State.UP -> {
                            Log.d(TAG, "✅ Tunnel is UP")
                            broadcastStateChange(STATE_CONNECTED)
                            updateNotification("Connected")
                        }
                        Tunnel.State.DOWN -> {
                            Log.d(TAG, "⭕ Tunnel is DOWN")
                            broadcastStateChange(STATE_DISCONNECTED)
                            stopSelf()
                        }
                        else -> {
                            Log.d(TAG, "⚠️ Tunnel state: $newState (not handled)")
                        }
                    }
                }
            }
            
            backend?.setState(tunnel, Tunnel.State.UP, wgConfig)
            Log.d(TAG, "✅ VPN connection initiated")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error connecting VPN", e)
            broadcastError("Connection failed: ${e.message}")
            stopSelf()
        }
    }
}
    
private fun startHttpTunnel(protocol: String, serverEndpoint: String, authToken: String) {
    httpTunnelJob?.cancel()
    httpTunnelJob = serviceScope.launch {
        try {
            Log.d(TAG, "🔵 Starting HTTP tunnel")
            Log.d(TAG, "   Protocol: $protocol")
            Log.d(TAG, "   Server: $serverEndpoint")
            
            // Extract hostname and USE PORT 8443 for HTTPS mimicry
            val host = serverEndpoint.split(":")[0]
            val port = 8443  // ALWAYS use 8443 for HTTP tunnel
            
            Log.d(TAG, "🔵 Connecting to $host:$port via TLS")
            
            // Use SSLSocket for HTTPS connections
            val sslContext = SSLContext.getInstance("TLS")
            
            // DEVELOPMENT ONLY: Trust all certificates
            val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
                override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
                override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
            })
            
            sslContext.init(null, trustAllCerts, java.security.SecureRandom())
            val sslSocketFactory = sslContext.socketFactory
            
            // Create SSL socket
            val sslSocket = sslSocketFactory.createSocket(host, port) as SSLSocket
            httpTunnelSocket = sslSocket
            
            // Start TLS handshake
            sslSocket.startHandshake()
            Log.d(TAG, "✅ TLS handshake successful")

            // Build and send HTTP request based on protocol
            val request = when (protocol.lowercase()) {
                "http", "https" -> buildHttpRequest(host, authToken)
                "teams" -> buildTeamsRequest(host, authToken)
                "google" -> buildGoogleRequest(host, authToken)
                "shaparak" -> buildShaparakRequest(host, authToken)
                "doh" -> buildDohRequest(host, authToken)
                "zoom" -> buildZoomRequest(host, authToken)
                "facetime" -> buildFacetimeRequest(host, authToken)
                "vk" -> buildVkRequest(host, authToken)
                "yandex" -> buildYandexRequest(host, authToken)
                "wechat" -> buildWechatRequest(host, authToken)
                else -> buildHttpRequest(host, authToken)
            }

            Log.d(TAG, "🔵 Sending $protocol mimicry request")
            val writer = OutputStreamWriter(sslSocket.outputStream, Charsets.UTF_8)
            writer.write(request)
            writer.flush()

            // ✅ READ THE SERVER'S RESPONSE
            Log.d(TAG, "🔵 Waiting for server response...")
            val reader = BufferedReader(InputStreamReader(sslSocket.inputStream, Charsets.UTF_8))
            val response = StringBuilder()
            var line: String?

            // Read HTTP response headers until empty line
            var headerCount = 0
            while (reader.readLine().also { line = it } != null && headerCount < 50) {
                headerCount++
                response.append(line).append("\n")
                Log.d(TAG, "   Response line: $line")
                if (line?.isEmpty() == true) {
                    // Empty line indicates end of headers
                    break
                }
            }

            val responseStr = response.toString()
            Log.d(TAG, "✅ HTTP tunnel established successfully")
            Log.d(TAG, "   Protocol: $protocol")
            Log.d(TAG, "   Response: ${responseStr.take(200)}")

            // Check if response was successful
            if (!responseStr.contains("200 OK") && !responseStr.contains("101 Switching Protocols")) {
                throw IOException("HTTP tunnel failed: $responseStr")
            }

            // Keep the socket open for the tunnel
            Log.d(TAG, "🔵 HTTP tunnel is now open, keeping connection alive...")
            
            // Keep the coroutine alive to maintain the tunnel
            delay(Long.MAX_VALUE)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ HTTP tunnel failed", e)
            httpTunnelSocket?.close()
            httpTunnelSocket = null
            // Don't throw - let WireGuard try direct connection as fallback
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// Protocol Mimicry Request Builders
// ═══════════════════════════════════════════════════════════════

// ✅ HTTP/HTTPS - Generic web traffic
private fun buildHttpRequest(host: String, authToken: String): String {
    return """
        POST / HTTP/1.1
        Host: $host
        Authorization: Bearer $authToken
        User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36
        Content-Type: application/octet-stream
        Accept: */*
        Accept-Encoding: gzip, deflate, br
        Connection: keep-alive
        
        
    """.trimIndent()
}

// ✅ Microsoft Teams - Video conferencing
private fun buildTeamsRequest(host: String, authToken: String): String {
    return """
        POST /teams/messages HTTP/1.1
        Host: $host
        Authorization: Bearer $authToken
        User-Agent: Mozilla/5.0 Teams/1.5.00.32283
        X-Ms-Client-Version: 1.0.0.2024010901
        X-Ms-Client-Type: desktop
        Content-Type: application/json
        Accept: application/json
        Connection: keep-alive
        
        
    """.trimIndent()
}

// ✅ Google Workspace - Drive, Meet, Calendar
private fun buildGoogleRequest(host: String, authToken: String): String {
    return """
        POST /google/ HTTP/1.1
        Host: $host
        Authorization: Bearer $authToken
        User-Agent: Mozilla/5.0 Chrome/120.0.0.0
        X-Goog-Api-Client: gl-java/1.0
        X-Goog-AuthUser: 0
        Content-Type: application/json
        Accept: application/json
        Connection: keep-alive
        
        
    """.trimIndent()
}

// ✅ Shaparak - Iranian banking system
private fun buildShaparakRequest(host: String, authToken: String): String {
    return """
        POST /shaparak/transaction HTTP/1.1
        Host: $host
        Authorization: Bearer $authToken
        User-Agent: ShaparakClient/2.0
        Content-Type: text/xml; charset=utf-8
        SOAPAction: "http://shaparak.ir/VerifyTransaction"
        Accept: text/xml
        Connection: keep-alive
        
        
    """.trimIndent()
}

// ✅ DNS over HTTPS
private fun buildDohRequest(host: String, authToken: String): String {
    return """
        POST /dns-query HTTP/1.1
        Host: $host
        Authorization: Bearer $authToken
        User-Agent: Mozilla/5.0
        Content-Type: application/dns-message
        Accept: application/dns-message
        Connection: keep-alive
        
        
    """.trimIndent()
}

// ✅ Zoom - Video conferencing
private fun buildZoomRequest(host: String, authToken: String): String {
    return """
        POST /zoom/ HTTP/1.1
        Host: $host
        Authorization: Bearer $authToken
        User-Agent: Mozilla/5.0 Zoom/5.16.0
        Content-Type: application/json
        Accept: application/json
        Connection: keep-alive
        
        
    """.trimIndent()
}

// ✅ FaceTime - Apple video calling
private fun buildFacetimeRequest(host: String, authToken: String): String {
    return """
        POST /facetime/ HTTP/1.1
        Host: $host
        Authorization: Bearer $authToken
        User-Agent: FaceTime/1.0 CFNetwork/1404.0.5
        X-Apple-Client-Application: FaceTime
        X-Apple-Client-Version: 1.0
        Content-Type: application/json
        Accept: application/json
        Connection: keep-alive
        
        
    """.trimIndent()
}

// ✅ VK - Russian social network
private fun buildVkRequest(host: String, authToken: String): String {
    return """
        POST /vk/ HTTP/1.1
        Host: $host
        Authorization: Bearer $authToken
        User-Agent: VKAndroidApp/7.26
        Content-Type: application/json
        Accept: application/json
        Connection: keep-alive
        
        
    """.trimIndent()
}

// ✅ Yandex - Russian services
private fun buildYandexRequest(host: String, authToken: String): String {
    return """
        POST /yandex/ HTTP/1.1
        Host: $host
        Authorization: Bearer $authToken
        User-Agent: Mozilla/5.0 YaBrowser/23.11.0
        Content-Type: application/json
        Accept: application/json
        Connection: keep-alive
        
        
    """.trimIndent()
}

// ✅ WeChat - Chinese messaging
private fun buildWechatRequest(host: String, authToken: String): String {
    return """
        POST /wechat/ HTTP/1.1
        Host: $host
        Authorization: Bearer $authToken
        User-Agent: MicroMessenger/8.0.37
        Content-Type: application/json
        Accept: application/json
        Connection: keep-alive
        
        
    """.trimIndent()
}
    
    private fun buildWireGuardConfig(
        privateKey: String,
        serverEndpoint: String,
        serverPublicKey: String,
        allowedIPs: String,
        dns: String,
        mtu: Int,
        allocatedIp: String
    ): Config {
        val configText = """
            [Interface]
            PrivateKey = $privateKey
            Address = $allocatedIp/32
            DNS = $dns
            MTU = $mtu
            
            [Peer]
            PublicKey = $serverPublicKey
            Endpoint = $serverEndpoint
            AllowedIPs = $allowedIPs
            PersistentKeepalive = 25
        """.trimIndent()
        
        Log.d(TAG, "🔵 WireGuard config:\n$configText")
        
        return Config.parse(configText.byteInputStream())
    }
    
    private fun disconnectVpn() {
        serviceScope.launch {
            try {
                Log.d(TAG, "🔵 Disconnecting VPN")
                broadcastStateChange(STATE_DISCONNECTING)
                
                // Close HTTP tunnel
                httpTunnelJob?.cancel()
                httpTunnelSocket?.close()
                httpTunnelSocket = null
                
                // Close VPN tunnel
                vpnInterface?.close()
                vpnInterface = null
                
                backend?.setState(
                    object : Tunnel {
                        override fun getName(): String = "OrbVPN"
                        override fun onStateChange(newState: Tunnel.State) {}
                    },
                    Tunnel.State.DOWN,
                    null
                )
                
                Log.d(TAG, "✅ VPN disconnected")
                broadcastStateChange(STATE_DISCONNECTED)
                stopForeground(true)
                stopSelf()
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error disconnecting VPN", e)
                broadcastError("Disconnection failed: ${e.message}")
            }
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OrbVPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
                setShowBadge(false)
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Notification channel created")
        }
    }
    
    private fun createNotification(status: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OrbVPN")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(status: String) {
        val notification = createNotification(status)
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
        Log.d(TAG, "🔵 Notification updated: $status")
    }
    
    private fun broadcastStateChange(state: String) {
        Log.d(TAG, "📢 Broadcasting state: $state")
        val intent = Intent(BROADCAST_STATE_CHANGED).apply {
            putExtra(EXTRA_STATE, state)
        }
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }
    
    private fun broadcastError(message: String) {
        Log.e(TAG, "📢 Broadcasting error: $message")
        val intent = Intent(BROADCAST_ERROR).apply {
            putExtra(EXTRA_ERROR_MESSAGE, message)
        }
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }
    
    override fun onRevoke() {
        super.onRevoke()
        Log.d(TAG, "⚠️ VPN permission revoked")
        disconnectVpn()
    }
    
    override fun onDestroy() {
        Log.d(TAG, "🔵 Service destroyed")
        serviceJob.cancel()
        httpTunnelSocket?.close()
        vpnInterface?.close()
        super.onDestroy()
    }
}