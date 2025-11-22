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
    private var localUdpProxy: LocalUdpProxy? = null

    private lateinit var protocolManager: ProtocolManager
    private var currentServerAddress: String = ""

    // Traffic monitoring
    private var trafficMonitorJob: Job? = null
    private var httpTunnelEstablished = false
    private var isMonitoringTraffic = false
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🔵 Service created")
        createNotificationChannel()
        backend = GoBackend(applicationContext)

        protocolManager = ProtocolManager(applicationContext)
        Log.i(TAG, "🧠 Smart Connect: ${if (protocolManager.isSmartConnectEnabled()) "ENABLED" else "DISABLED"}")
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
                    Log.w(TAG, "⚠️ Config map is null, ignoring duplicate connect call")
                    // Don't stop the service - it's already running with previous config
                    // Just ignore this duplicate call
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

            // Store server address for protocol management
            currentServerAddress = serverEndpoint

            // Reset HTTP tunnel flag
            httpTunnelEstablished = false

            // Start HTTP tunnel with Smart Connect and WAIT for it to complete
            val tunnelSuccess = if (protocol.isNotEmpty()) {
                startSmartHttpTunnelAndWait(serverEndpoint, authToken, privateKey)
            } else {
                false
            }

            if (!tunnelSuccess) {
                Log.e(TAG, "❌ Failed to establish HTTP tunnel")
                broadcastError("Failed to establish secure tunnel")
                stopSelf()
                return@launch
            }

            Log.d(TAG, "✅ HTTP tunnel established, proceeding with WireGuard setup")

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
                            // Start traffic monitoring
                            startTrafficMonitoring()
                        }
                        Tunnel.State.DOWN -> {
                            Log.d(TAG, "⭕ Tunnel is DOWN")
                            stopTrafficMonitoring()
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

private suspend fun startSmartHttpTunnelAndWait(
    serverEndpoint: String,
    authToken: String,
    publicKey: String
): Boolean {
    return try {
            if (protocolManager.isSmartConnectEnabled()) {
                // Smart Connect ENABLED - try protocols with fallback
                Log.i(TAG, "═══════════════════════════════════════")
                Log.i(TAG, "🧠 SMART CONNECT: ENABLED")
                Log.i(TAG, "═══════════════════════════════════════")

                val protocols = protocolManager.getFallbackProtocols(serverEndpoint)
                Log.i(TAG, "Will try ${protocols.size} protocols: ${protocols.joinToString(", ")}")

                for ((index, protocol) in protocols.withIndex()) {
                    val protocolName = protocolManager.getProtocolDisplayName(protocol)
                    val isRemembered = index == 0 && protocols.size > 1

                    Log.i(TAG, "")
                    Log.i(TAG, "═══════════════════════════════════════")
                    Log.i(TAG, "🔄 Attempt ${index + 1}/${protocols.size}: $protocolName")
                    if (isRemembered) {
                        Log.i(TAG, "   (Last successful protocol)")
                    }
                    Log.i(TAG, "═══════════════════════════════════════")

                    val success = tryProtocol(protocol, serverEndpoint, authToken, publicKey)

                    if (success) {
                        Log.i(TAG, "✅ SUCCESS with $protocol!")
                        protocolManager.recordSuccess(serverEndpoint, protocol)
                        protocolManager.printStats(serverEndpoint)
                        httpTunnelEstablished = true
                        return true
                    } else {
                        Log.w(TAG, "❌ Failed with $protocol")
                        protocolManager.recordFailure(serverEndpoint, protocol)

                        if (index < protocols.size - 1) {
                            Log.i(TAG, "⏳ Waiting 2 seconds before trying next protocol...")
                            delay(2000)
                        }
                    }
                }

                // All protocols failed
                Log.e(TAG, "❌ Unable to connect with any protocol")
                broadcastError("Unable to connect with any protocol")
                return false

            } else {
                // Smart Connect DISABLED - use default HTTPS
                Log.i(TAG, "═══════════════════════════════════════")
                Log.i(TAG, "🔵 Smart Connect: DISABLED")
                Log.i(TAG, "   Using default protocol (https)")
                Log.i(TAG, "═══════════════════════════════════════")

                val success = tryProtocol("https", serverEndpoint, authToken, publicKey)

                if (success) {
                    httpTunnelEstablished = true
                    return true
                } else {
                    broadcastError("Connection failed with HTTPS protocol")
                    return false
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in Smart Connect system", e)
            broadcastError("Connection failed: ${e.message}")
            return false
        }
    }

private suspend fun tryProtocol(
    protocol: String,
    serverEndpoint: String,
    authToken: String,
    publicKey: String
): Boolean {
    return try {
            Log.d(TAG, "🔵 Starting HTTP tunnel")
            Log.d(TAG, "   Protocol: $protocol")
            Log.d(TAG, "   Server: $serverEndpoint")
            
            // Parse server endpoint
            val parts = serverEndpoint.split(":")
            if (parts.size != 2) {
                Log.e(TAG, "❌ Invalid server endpoint: $serverEndpoint")
                return false
            }

            val host = parts[0]
            val wgPort = parts[1].toIntOrNull() ?: run {
                Log.e(TAG, "❌ Invalid port: ${parts[1]}")
                return false
            }
            
            // Connect to HTTPS port (8443) for tunnel establishment
            val tunnelPort = 8443
            Log.d(TAG, "🔵 Connecting to $host:$tunnelPort via TLS")
            
            // Create TLS socket with disabled certificate validation (DEVELOPMENT ONLY!)
            Log.d(TAG, "🟢 CREATING CUSTOM SSL CONTEXT")
            
            // Create trust manager that accepts all certificates
            val trustAllCerts = arrayOf<javax.net.ssl.TrustManager>(
                object : javax.net.ssl.X509TrustManager {
                    override fun checkClientTrusted(chain: Array<java.security.cert.X509Certificate>, authType: String) {}
                    override fun checkServerTrusted(chain: Array<java.security.cert.X509Certificate>, authType: String) {}
                    override fun getAcceptedIssuers(): Array<java.security.cert.X509Certificate> = arrayOf()
                }
            )
            
            // Create SSL context
            val sslContext = javax.net.ssl.SSLContext.getInstance("TLS")
            sslContext.init(null, trustAllCerts, java.security.SecureRandom())
            
            // Create socket factory
            val socketFactory = sslContext.socketFactory
            
            Log.d(TAG, "🟢 CREATING SSL SOCKET")
            val sslSocket = socketFactory.createSocket(host, tunnelPort) as javax.net.ssl.SSLSocket

            // Set socket timeouts to prevent hanging indefinitely
            sslSocket.soTimeout = 15000  // 15 seconds read timeout
            Log.d(TAG, "✅ Socket timeout set to 15 seconds")

            Log.d(TAG, "🟢 SSL SOCKET CREATED WITH CERT VALIDATION DISABLED")
            Log.w(TAG, "⚠️ WARNING: Certificate validation is disabled! This is for development only!")

            httpTunnelSocket = sslSocket
            
            // Get selected VPN type (for future VLESS support)
            val vpnType = "wireguard"
            
            Log.d(TAG, "🟢 BUILDING REQUEST FOR PROTOCOL: $protocol")
            
            // Build HTTP POST request for tunnel establishment
            val request = when (protocol.lowercase()) {
                "https", "http" -> buildHttpRequest(host, authToken, vpnType)
                "teams" -> buildTeamsRequest(host, authToken, vpnType)
                "google" -> buildGoogleRequest(host, authToken, vpnType)
                "shaparak" -> buildShaparakRequest(host, authToken, vpnType)
                "doh" -> buildDohRequest(host, authToken, vpnType)
                "zoom" -> buildZoomRequest(host, authToken, vpnType)
                "facetime" -> buildFacetimeRequest(host, authToken, vpnType)
                "vk" -> buildVkRequest(host, authToken, vpnType)
                "yandex" -> buildYandexRequest(host, authToken, vpnType)
                "wechat" -> buildWechatRequest(host, authToken, vpnType)
                else -> buildHttpRequest(host, authToken, vpnType)
            }
            
            Log.d(TAG, "🔵 Sending $protocol mimicry request")
            Log.d(TAG, "   Request preview: ${request.take(100)}...")
            
            Log.d(TAG, "🟢 GETTING OUTPUT STREAM")
            val writer = OutputStreamWriter(sslSocket.getOutputStream())
            
            Log.d(TAG, "🟢 WRITING REQUEST")
            writer.write(request)
            
            Log.d(TAG, "🟢 FLUSHING REQUEST")
            writer.flush()
            
            Log.d(TAG, "🟢 REQUEST SENT, READING RESPONSE")
            
            // Read response headers
            Log.d(TAG, "🔵 Waiting for server response...")
            val reader = BufferedReader(InputStreamReader(sslSocket.getInputStream()))
            
            Log.d(TAG, "🟢 READING STATUS LINE")
            
            // Read status line
            val statusLine = reader.readLine()
            Log.d(TAG, "   Response line: $statusLine")
            
            if (statusLine == null || !statusLine.contains("200")) {
                Log.e(TAG, "❌ Server rejected tunnel: $statusLine")
                sslSocket.close()
                return false
            }
            
            Log.d(TAG, "🟢 STATUS LINE OK, READING HEADERS")
            
            // Read headers until empty line
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                Log.d(TAG, "   Response line: $line")
                if (line?.isEmpty() == true) break
            }
            
            Log.d(TAG, "✅ HTTP tunnel established successfully")
            Log.d(TAG, "🔵 HTTP tunnel is now open, forwarding WireGuard packets...")

            // Start LocalUdpProxy to forward packets between WireGuard and HTTPS tunnel
            val protocolName = protocolManager.getProtocolDisplayName(protocol)
            Log.d(TAG, "🔵 Starting LocalUdpProxy with protocol: $protocolName")

            localUdpProxy = LocalUdpProxy(
                sslSocket,
                serviceScope,
                onTunnelFailure = {
                    Log.e(TAG, "🔴 HTTPS tunnel failed, triggering automatic reconnection...")
                    // Reconnect the HTTP tunnel
                    serviceScope.launch {
                        reconnectHttpTunnel(serverEndpoint, authToken, publicKey)
                    }
                }
            )
            localUdpProxy?.start()

            Log.d(TAG, "✅ LocalUdpProxy started successfully")

            true // Success!

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error establishing HTTP tunnel with protocol: $protocol", e)
            Log.e(TAG, "   Exception: ${e.message}")
            httpTunnelSocket?.close()
            httpTunnelSocket = null
            false // Failed
        }
    }

    /**
     * Reconnect HTTP tunnel when it fails
     */
    private suspend fun reconnectHttpTunnel(
        serverEndpoint: String,
        authToken: String,
        publicKey: String
    ) {
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🔄 Reconnecting HTTP tunnel...")
        Log.d(TAG, "═══════════════════════════════════════")

        // Stop current proxy
        localUdpProxy?.stop()
        localUdpProxy = null

        // Close current socket
        httpTunnelSocket?.close()
        httpTunnelSocket = null

        // Wait a bit before reconnecting
        delay(2000)

        // Try to reconnect using Smart Connect
        if (protocolManager.isSmartConnectEnabled()) {
            Log.d(TAG, "🧠 Using Smart Connect for reconnection")

            val protocols = protocolManager.getFallbackProtocols(serverEndpoint)
            Log.d(TAG, "🔄 Will try ${protocols.size} protocols: ${protocols.joinToString(", ")}")

            for ((index, protocol) in protocols.withIndex()) {
                val protocolName = protocolManager.getProtocolDisplayName(protocol)
                Log.d(TAG, "🔄 Reconnection attempt ${index + 1}/${protocols.size}: $protocolName")

                val success = tryProtocol(protocol, serverEndpoint, authToken, publicKey)

                if (success) {
                    protocolManager.recordSuccess(serverEndpoint, protocol)
                    Log.d(TAG, "✅ Reconnected successfully with protocol: $protocolName")
                    return
                } else {
                    protocolManager.recordFailure(serverEndpoint, protocol)
                    if (index < protocols.size - 1) {
                        Log.d(TAG, "⏳ Waiting 2 seconds before trying next protocol...")
                        delay(2000)
                    }
                }
            }

            // All protocols failed
            Log.e(TAG, "❌ All reconnection attempts failed")
            broadcastError("Reconnection failed: Unable to reconnect with any protocol")

        } else {
            // Smart Connect disabled, use HTTPS only
            Log.d(TAG, "🔵 Smart Connect disabled - using HTTPS for reconnection")
            val success = tryProtocol("https", serverEndpoint, authToken, publicKey)

            if (success) {
                Log.d(TAG, "✅ Reconnected successfully with HTTPS")
            } else {
                Log.e(TAG, "❌ Reconnection failed with HTTPS")
                broadcastError("Reconnection failed: Unable to reconnect")
            }
        }
    }

    // Get user's selected VPN type from preferences or config
    private fun getSelectedVpnType(): String {
        // In the future, this could read from user settings
        // For now, default to WireGuard
        return "wireguard"

        // Later when VLESS is added:
        // return sharedPreferences.getString("vpn_type", "wireguard") ?: "wireguard"
    }

    // ✅ HTTP/HTTPS - Generic web traffic
    private fun buildHttpRequest(host: String, authToken: String, vpnType: String = "wireguard"): String {
        return "POST /vpn/tunnel?type=$vpnType&protocol=https HTTP/1.1\r\n" +
               "Host: $host\r\n" +
               "Authorization: Bearer $authToken\r\n" +
               "X-VPN-Type: $vpnType\r\n" +
               "X-Protocol: https\r\n" +
               "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36\r\n" +
               "Content-Type: application/octet-stream\r\n" +
               "Accept: */*\r\n" +
               "Accept-Encoding: gzip, deflate, br\r\n" +
               "Connection: keep-alive\r\n" +
               "\r\n"
    }

    // ✅ Microsoft Teams - Video conferencing
    private fun buildTeamsRequest(host: String, authToken: String, vpnType: String = "wireguard"): String {
        return "POST /vpn/tunnel?type=$vpnType&protocol=teams HTTP/1.1\r\n" +
               "Host: $host\r\n" +
               "Authorization: Bearer $authToken\r\n" +
               "X-VPN-Type: $vpnType\r\n" +
               "X-Protocol: teams\r\n" +
               "User-Agent: Mozilla/5.0 Teams/1.5.00.32283\r\n" +
               "X-Ms-Client-Version: 1.0.0.2024010901\r\n" +
               "X-Ms-Client-Type: desktop\r\n" +
               "Content-Type: application/json\r\n" +
               "Accept: application/json\r\n" +
               "Connection: keep-alive\r\n" +
               "\r\n"
    }

    // ✅ Google Workspace - Drive, Meet, Calendar
    private fun buildGoogleRequest(host: String, authToken: String, vpnType: String = "wireguard"): String {
        return "POST /vpn/tunnel?type=$vpnType&protocol=google HTTP/1.1\r\n" +
               "Host: $host\r\n" +
               "Authorization: Bearer $authToken\r\n" +
               "X-VPN-Type: $vpnType\r\n" +
               "X-Protocol: google\r\n" +
               "User-Agent: Mozilla/5.0 Chrome/120.0.0.0\r\n" +
               "X-Goog-Api-Client: gl-java/1.0\r\n" +
               "X-Goog-AuthUser: 0\r\n" +
               "Content-Type: application/json\r\n" +
               "Accept: application/json\r\n" +
               "Connection: keep-alive\r\n" +
               "\r\n"
    }

    // ✅ Shaparak - Iranian banking system
    private fun buildShaparakRequest(host: String, authToken: String, vpnType: String = "wireguard"): String {
        return "POST /vpn/tunnel?type=$vpnType&protocol=shaparak HTTP/1.1\r\n" +
               "Host: $host\r\n" +
               "Authorization: Bearer $authToken\r\n" +
               "X-VPN-Type: $vpnType\r\n" +
               "X-Protocol: shaparak\r\n" +
               "User-Agent: ShaparakClient/2.0\r\n" +
               "Content-Type: text/xml; charset=utf-8\r\n" +
               "SOAPAction: \"http://shaparak.ir/VerifyTransaction\"\r\n" +
               "Accept: text/xml\r\n" +
               "Connection: keep-alive\r\n" +
               "\r\n"
    }

    // ✅ DNS over HTTPS
    private fun buildDohRequest(host: String, authToken: String, vpnType: String = "wireguard"): String {
        return "POST /vpn/tunnel?type=$vpnType&protocol=doh HTTP/1.1\r\n" +
               "Host: $host\r\n" +
               "Authorization: Bearer $authToken\r\n" +
               "X-VPN-Type: $vpnType\r\n" +
               "X-Protocol: doh\r\n" +
               "User-Agent: Mozilla/5.0\r\n" +
               "Content-Type: application/dns-message\r\n" +
               "Accept: application/dns-message\r\n" +
               "Connection: keep-alive\r\n" +
               "\r\n"
    }

    // ✅ Zoom - Video conferencing
    private fun buildZoomRequest(host: String, authToken: String, vpnType: String = "wireguard"): String {
        return "POST /vpn/tunnel?type=$vpnType&protocol=zoom HTTP/1.1\r\n" +
               "Host: $host\r\n" +
               "Authorization: Bearer $authToken\r\n" +
               "X-VPN-Type: $vpnType\r\n" +
               "X-Protocol: zoom\r\n" +
               "User-Agent: Mozilla/5.0 Zoom/5.16.0\r\n" +
               "Content-Type: application/json\r\n" +
               "Accept: application/json\r\n" +
               "Connection: keep-alive\r\n" +
               "\r\n"
    }

    // ✅ FaceTime - Apple video calling
    private fun buildFacetimeRequest(host: String, authToken: String, vpnType: String = "wireguard"): String {
        return "POST /vpn/tunnel?type=$vpnType&protocol=facetime HTTP/1.1\r\n" +
               "Host: $host\r\n" +
               "Authorization: Bearer $authToken\r\n" +
               "X-VPN-Type: $vpnType\r\n" +
               "X-Protocol: facetime\r\n" +
               "User-Agent: FaceTime/1.0 CFNetwork/1404.0.5\r\n" +
               "X-Apple-Client-Application: FaceTime\r\n" +
               "X-Apple-Client-Version: 1.0\r\n" +
               "Content-Type: application/json\r\n" +
               "Accept: application/json\r\n" +
               "Connection: keep-alive\r\n" +
               "\r\n"
    }

    // ✅ VK - Russian social network
    private fun buildVkRequest(host: String, authToken: String, vpnType: String = "wireguard"): String {
        return "POST /vpn/tunnel?type=$vpnType&protocol=vk HTTP/1.1\r\n" +
               "Host: $host\r\n" +
               "Authorization: Bearer $authToken\r\n" +
               "X-VPN-Type: $vpnType\r\n" +
               "X-Protocol: vk\r\n" +
               "User-Agent: VKAndroidApp/7.26\r\n" +
               "Content-Type: application/json\r\n" +
               "Accept: application/json\r\n" +
               "Connection: keep-alive\r\n" +
               "\r\n"
    }

    // ✅ Yandex - Russian services
    private fun buildYandexRequest(host: String, authToken: String, vpnType: String = "wireguard"): String {
        return "POST /vpn/tunnel?type=$vpnType&protocol=yandex HTTP/1.1\r\n" +
               "Host: $host\r\n" +
               "Authorization: Bearer $authToken\r\n" +
               "X-VPN-Type: $vpnType\r\n" +
               "X-Protocol: yandex\r\n" +
               "User-Agent: Mozilla/5.0 YaBrowser/23.11.0\r\n" +
               "Content-Type: application/json\r\n" +
               "Accept: application/json\r\n" +
               "Connection: keep-alive\r\n" +
               "\r\n"
    }

    // ✅ WeChat - Chinese messaging
    private fun buildWechatRequest(host: String, authToken: String, vpnType: String = "wireguard"): String {
        return "POST /vpn/tunnel?type=$vpnType&protocol=wechat HTTP/1.1\r\n" +
               "Host: $host\r\n" +
               "Authorization: Bearer $authToken\r\n" +
               "X-VPN-Type: $vpnType\r\n" +
               "X-Protocol: wechat\r\n" +
               "User-Agent: MicroMessenger/8.0.37\r\n" +
               "Content-Type: application/json\r\n" +
               "Accept: application/json\r\n" +
               "Connection: keep-alive\r\n" +
               "\r\n"
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
        // Use local endpoint for packet encapsulation
        // LocalUdpProxy forwards to HTTPS tunnel
        val localProxyEndpoint = "127.0.0.1:51820"

        val configText = """
            [Interface]
            PrivateKey = $privateKey
            Address = $allocatedIp/32
            DNS = $dns
            MTU = $mtu

            [Peer]
            PublicKey = $serverPublicKey
            Endpoint = $localProxyEndpoint
            AllowedIPs = $allowedIPs
            PersistentKeepalive = 25
        """.trimIndent()

        Log.d(TAG, "🔵 WireGuard config:")
        Log.d(TAG, "   Using LOCAL endpoint: $localProxyEndpoint (packet encapsulation)")
        Log.d(TAG, "   Actual server: $serverEndpoint (via HTTPS tunnel)")

        return Config.parse(configText.byteInputStream())
    }
    
    private fun disconnectVpn() {
        serviceScope.launch {
            try {
                Log.d(TAG, "🔵 Disconnecting VPN")
                broadcastStateChange(STATE_DISCONNECTING)

                // Stop LocalUdpProxy
                localUdpProxy?.stop()
                localUdpProxy = null

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
    
    /**
     * Start traffic monitoring to detect when connected but no traffic flows
     */
    private fun startTrafficMonitoring() {
        if (isMonitoringTraffic) {
            Log.d(TAG, "⚠️ Traffic monitoring already running")
            return
        }

        isMonitoringTraffic = true
        trafficMonitorJob = serviceScope.launch {
            Log.d(TAG, "🚀 Starting traffic monitoring...")
            delay(10000) // Wait 10 seconds after connection before checking

            Log.d(TAG, "🔍 Checking if traffic is flowing...")

            // Get initial packet counts from LocalUdpProxy
            val initialPacketsToServer = localUdpProxy?.getPacketsToServer() ?: 0
            val initialPacketsFromServer = localUdpProxy?.getPacketsFromServer() ?: 0

            Log.d(TAG, "📊 Initial traffic stats:")
            Log.d(TAG, "   To server: $initialPacketsToServer packets")
            Log.d(TAG, "   From server: $initialPacketsFromServer packets")

            // Wait 15 more seconds
            delay(15000)

            // Check if traffic increased
            val currentPacketsToServer = localUdpProxy?.getPacketsToServer() ?: 0
            val currentPacketsFromServer = localUdpProxy?.getPacketsFromServer() ?: 0

            Log.d(TAG, "📊 Current traffic stats:")
            Log.d(TAG, "   To server: $currentPacketsToServer packets")
            Log.d(TAG, "   From server: $currentPacketsFromServer packets")

            val packetsToServerDelta = currentPacketsToServer - initialPacketsToServer
            val packetsFromServerDelta = currentPacketsFromServer - initialPacketsFromServer

            Log.d(TAG, "📊 Traffic delta in last 15 seconds:")
            Log.d(TAG, "   To server: +$packetsToServerDelta packets")
            Log.d(TAG, "   From server: +$packetsFromServerDelta packets")

            // If very little or no traffic in 15 seconds, there might be a problem
            if (packetsFromServerDelta < 5) {
                Log.e(TAG, "❌ TRAFFIC MONITORING ALERT: Connected but no traffic from server!")
                Log.e(TAG, "   Only $packetsFromServerDelta packets received in 15 seconds")
                broadcastError("Connected but no internet traffic. Connection may be stale.")
                updateNotification("Connected (No Internet)")

                // Attempt to reconnect
                Log.d(TAG, "🔄 Attempting to reconnect due to no traffic...")
                disconnectVpn()
            } else {
                Log.d(TAG, "✅ Traffic monitoring: Connection is healthy")
                Log.d(TAG, "   $packetsFromServerDelta packets received from server")
            }

            isMonitoringTraffic = false
        }
    }

    /**
     * Stop traffic monitoring
     */
    private fun stopTrafficMonitoring() {
        Log.d(TAG, "🛑 Stopping traffic monitoring...")
        trafficMonitorJob?.cancel()
        trafficMonitorJob = null
        isMonitoringTraffic = false
    }

    override fun onDestroy() {
        Log.d(TAG, "🔵 Service destroyed")
        stopTrafficMonitoring()
        localUdpProxy?.stop()
        serviceJob.cancel()
        httpTunnelSocket?.close()
        vpnInterface?.close()
        super.onDestroy()
    }
}