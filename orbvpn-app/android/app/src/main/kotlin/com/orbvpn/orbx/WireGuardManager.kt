package com.orbvpn.orbx\n\nclass WireGuardManager {}\n

import android.content.Context
import android.util.Log
import com.wireguard.android.backend.GoBackend
import com.wireguard.config.Config
import com.wireguard.config.Interface
import com.wireguard.config.Peer
import com.wireguard.crypto.Key
import com.wireguard.crypto.KeyPair
import java.net.InetSocketAddress

class WireGuardManager(private val context: Context) {
    private val TAG = "WireGuardManager"
    private var backend: GoBackend? = null
    private var currentTunnel: WireGuardTunnel? = null
    
    init {
        try {
            backend = GoBackend(context)
            Log.d(TAG, "WireGuard backend initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize WireGuard backend", e)
        }
    }

    // Generate WireGuard keypair
    fun generateKeypair(): Map<String, String> {
        val keypair = KeyPair()
        return mapOf(
            "privateKey" to keypair.privateKey.toBase64(),
            "publicKey" to keypair.publicKey.toBase64()
        )
    }

    // Connect to WireGuard server
    fun connect(configData: Map<String, Any>): Boolean {
        try {
            Log.d(TAG, "Connecting to WireGuard...")

            // Parse configuration
            val privateKey = configData["privateKey"] as String
            val serverPublicKey = configData["serverPublicKey"] as String
            val endpoint = configData["endpoint"] as String
            val allocatedIp = configData["allocatedIp"] as String
            val dns = configData["dns"] as List<String>
            val mtu = (configData["mtu"] as Int).toString()

            // Build WireGuard config
            val interfaceBuilder = Interface.Builder()
                .parsePrivateKey(privateKey)
                .parseAddresses(allocatedIp)
                .parseDnsServers(dns.joinToString(","))
                .parseMtu(mtu)

            val peerBuilder = Peer.Builder()
                .parsePublicKey(serverPublicKey)
                .parseEndpoint(endpoint)
                .parseAllowedIPs("0.0.0.0/0, ::/0")
                .parsePersistentKeepalive("25")

            val config = Config.Builder()
                .setInterface(interfaceBuilder.build())
                .addPeer(peerBuilder.build())
                .build()

            // Create tunnel
            currentTunnel = WireGuardTunnel("OrbX", config)

            // Start tunnel
            backend?.setState(
                currentTunnel!!,
                com.wireguard.android.backend.Tunnel.State.UP,
                null
            )

            Log.d(TAG, "WireGuard tunnel established")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect", e)
            return false
        }
    }

    // Disconnect from WireGuard
    fun disconnect(): Boolean {
        try {
            if (currentTunnel != null) {
                backend?.setState(
                    currentTunnel!!,
                    com.wireguard.android.backend.Tunnel.State.DOWN,
                    null
                )
                currentTunnel = null
                Log.d(TAG, "WireGuard tunnel disconnected")
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to disconnect", e)
            return false
        }
    }

    // Get connection status
    fun getStatus(): Map<String, Any> {
        val isConnected = currentTunnel != null && 
            backend?.getState(currentTunnel!!) == com.wireguard.android.backend.Tunnel.State.UP

        return mapOf(
            "connected" to isConnected,
            "tunnel" to (currentTunnel?.name ?: "")
        )
    }

    // Get statistics
    fun getStatistics(): Map<String, Long> {
        return try {
            if (currentTunnel != null) {
                val stats = backend?.getStatistics(currentTunnel!!)
                mapOf(
                    "bytesSent" to (stats?.totalTx() ?: 0L),
                    "bytesReceived" to (stats?.totalRx() ?: 0L)
                )
            } else {
                mapOf("bytesSent" to 0L, "bytesReceived" to 0L)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get statistics", e)
            mapOf("bytesSent" to 0L, "bytesReceived" to 0L)
        }
    }

    // Internal tunnel class
    private inner class WireGuardTunnel(
        private val tunnelName: String,
        private val config: Config
    ) : com.wireguard.android.backend.Tunnel {
        
        override fun getName(): String = tunnelName

        override fun onStateChange(newState: com.wireguard.android.backend.Tunnel.State) {
            Log.d(TAG, "Tunnel state changed: $newState")
        }
    }
}