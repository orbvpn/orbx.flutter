package com.orbvpn.orbx

import android.util.Log
import kotlinx.coroutines.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import javax.net.ssl.SSLSocket

/**
 * LocalUdpProxy
 *
 * Creates a local UDP server that WireGuard connects to
 * Forwards WireGuard packets through HTTPS tunnel to the remote server
 *
 * Architecture:
 * 1. WireGuard sends encrypted packets to 127.0.0.1:51820 (local)
 * 2. LocalUdpProxy reads from UDP socket
 * 3. Forwards packets to HTTPS tunnel (disguised as protocol mimicry)
 * 4. Server receives from HTTPS and forwards to its WireGuard daemon
 * 5. Server sends responses back through HTTPS
 * 6. LocalUdpProxy writes responses to local UDP socket
 * 7. WireGuard reads from local UDP socket
 */
class LocalUdpProxy(
    private val httpsTunnelSocket: SSLSocket,
    private val scope: CoroutineScope
) {
    private val TAG = "LocalUdpProxy"

    private var udpSocket: DatagramSocket? = null
    private var isRunning = false

    // WireGuard will connect to this local address
    private val LOCAL_IP = "127.0.0.1"
    private val LOCAL_PORT = 51820

    // Statistics
    private var packetsToServer = 0L
    private var packetsFromServer = 0L
    private var bytesToServer = 0L
    private var bytesFromServer = 0L

    // Store WireGuard's address so we can send responses back
    private var wireGuardAddress: InetAddress? = null
    private var wireGuardPort: Int = 0

    /**
     * Start the local UDP proxy
     */
    fun start() {
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🚀 Starting local UDP proxy...")
        Log.d(TAG, "═══════════════════════════════════════")

        isRunning = true

        try {
            // Create local UDP socket
            udpSocket = DatagramSocket(LOCAL_PORT, InetAddress.getByName(LOCAL_IP))

            Log.d(TAG, "✅ Local UDP server listening on $LOCAL_IP:$LOCAL_PORT")
            Log.d(TAG, "   WireGuard will send packets here")

            // Start packet forwarders
            scope.launch(Dispatchers.IO) {
                forwardUdpToHttps()
            }

            scope.launch(Dispatchers.IO) {
                forwardHttpsToUdp()
            }

            Log.d(TAG, "✅ Local UDP proxy started")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start UDP proxy", e)
            stop()
        }
    }

    /**
     * Forward packets from local UDP (WireGuard) to HTTPS tunnel
     */
    private suspend fun forwardUdpToHttps() {
        Log.d(TAG, "📤 Starting UDP → HTTPS forwarder...")

        val buffer = ByteArray(2048) // Standard MTU

        while (isRunning) {
            try {
                val packet = DatagramPacket(buffer, buffer.size)
                udpSocket?.receive(packet)

                // Store WireGuard's address for sending responses back
                wireGuardAddress = packet.address
                wireGuardPort = packet.port

                // Extract packet data
                val data = packet.data.copyOf(packet.length)

                packetsToServer++
                bytesToServer += data.size

                // Log every 100 packets to avoid spam
                if (packetsToServer % 100 == 0L) {
                    Log.d(TAG, "📤 Forwarded packet #$packetsToServer (${data.size} bytes) from WireGuard to HTTPS")
                    printStats()
                }

                // Forward to HTTPS tunnel (raw packet, no framing)
                // Server expects raw WireGuard packets without length prefix
                synchronized(httpsTunnelSocket) {
                    httpsTunnelSocket.outputStream.write(data)
                    httpsTunnelSocket.outputStream.flush()
                }

            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "❌ Error forwarding UDP → HTTPS", e)
                    delay(100) // Backoff on error
                }
            }
        }

        Log.d(TAG, "📤 UDP → HTTPS forwarder stopped")
    }

    /**
     * Forward packets from HTTPS tunnel to local UDP (WireGuard)
     */
    private suspend fun forwardHttpsToUdp() {
        Log.d(TAG, "📥 Starting HTTPS → UDP forwarder...")

        val buffer = ByteArray(2048) // Standard MTU

        while (isRunning) {
            try {
                // Read raw packet from HTTPS tunnel (no length prefix)
                val n = httpsTunnelSocket.inputStream.read(buffer)
                if (n == -1) {
                    Log.w(TAG, "⚠️ HTTPS tunnel closed by server")
                    isRunning = false
                    break
                }

                if (n == 0) {
                    continue
                }

                // Extract packet data
                val data = buffer.copyOf(n)

                packetsFromServer++
                bytesFromServer += data.size

                // Log every 100 packets to avoid spam
                if (packetsFromServer % 100 == 0L) {
                    Log.d(TAG, "📥 Forwarded packet #$packetsFromServer (${data.size} bytes) from HTTPS to WireGuard")
                    printStats()
                }

                // Forward to WireGuard via local UDP
                if (wireGuardAddress != null && wireGuardPort != 0) {
                    val packet = DatagramPacket(data, data.size, wireGuardAddress, wireGuardPort)
                    udpSocket?.send(packet)
                } else {
                    Log.w(TAG, "⚠️ Cannot send to WireGuard - no address stored yet")
                }

            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "❌ Error forwarding HTTPS → UDP", e)
                    delay(100) // Backoff on error
                }
            }
        }

        Log.d(TAG, "📥 HTTPS → UDP forwarder stopped")
    }

    /**
     * Print statistics
     */
    private fun printStats() {
        Log.d(TAG, "📊 Proxy Statistics:")
        Log.d(TAG, "   To server:   $packetsToServer packets (${formatBytes(bytesToServer)})")
        Log.d(TAG, "   From server: $packetsFromServer packets (${formatBytes(bytesFromServer)})")
    }

    /**
     * Stop the proxy
     */
    fun stop() {
        Log.d(TAG, "🛑 Stopping local UDP proxy...")

        isRunning = false

        try {
            udpSocket?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing UDP socket", e)
        }

        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "📊 Final Proxy Statistics:")
        Log.d(TAG, "   Total to server:   $packetsToServer packets (${formatBytes(bytesToServer)})")
        Log.d(TAG, "   Total from server: $packetsFromServer packets (${formatBytes(bytesFromServer)})")
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "✅ Local UDP proxy stopped")
    }

    /**
     * Format bytes for display
     */
    private fun formatBytes(bytes: Long): String {
        return when {
            bytes < 1024 -> "$bytes B"
            bytes < 1024 * 1024 -> "${bytes / 1024} KB"
            else -> "${bytes / (1024 * 1024)} MB"
        }
    }
}
