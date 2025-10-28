package com.orbvpn.orbx

import android.os.ParcelFileDescriptor
import android.util.Log
import kotlinx.coroutines.*
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer

/**
 * TunPacketInterceptor
 * 
 * Intercepts packets from WireGuard TUN interface and routes them through HTTP tunnel
 * This implements Option 1: Client-Side Packet Tunneling
 * 
 * Flow:
 * 1. Read IP packets from TUN interface (created by WireGuard)
 * 2. Send packets via HTTP tunnel (using protocol mimicry)
 * 3. Receive response packets from HTTP tunnel
 * 4. Write response packets back to TUN interface
 */
class TunPacketInterceptor(
    private val tunInterface: ParcelFileDescriptor,
    private val httpTunnelHandler: HttpTunnelHandler,
    private val scope: CoroutineScope
) {
    private val TAG = "TunPacketInterceptor"
    
    private var inputStream: FileInputStream? = null
    private var outputStream: FileOutputStream? = null
    
    @Volatile
    private var isRunning = false
    
    private val packetBuffer = ByteBuffer.allocate(32768) // 32KB buffer
    
    // Statistics
    private var packetsRead = 0L
    private var packetsWritten = 0L
    private var bytesRead = 0L
    private var bytesWritten = 0L
    
    /**
     * Start intercepting packets
     */
    fun start() {
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🚀 Starting TUN packet interceptor...")
        Log.d(TAG, "═══════════════════════════════════════")
        
        isRunning = true
        
        try {
            inputStream = FileInputStream(tunInterface.fileDescriptor)
            outputStream = FileOutputStream(tunInterface.fileDescriptor)
            
            Log.d(TAG, "✅ TUN interface streams opened")
            Log.d(TAG, "   Input stream: $inputStream")
            Log.d(TAG, "   Output stream: $outputStream")
            
            // Start packet reader (reads FROM TUN, sends TO HTTP tunnel)
            scope.launch(Dispatchers.IO) {
                readPacketsFromTun()
            }
            
            // Start packet writer (receives FROM HTTP tunnel, writes TO TUN)
            scope.launch(Dispatchers.IO) {
                receivePacketsFromTunnel()
            }
            
            Log.d(TAG, "✅ TUN packet interceptor started")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start packet interceptor", e)
            stop()
        }
    }
    
    /**
     * Read packets from TUN interface and send via HTTP tunnel
     */
    private suspend fun readPacketsFromTun() {
        Log.d(TAG, "📖 Starting packet reader thread...")
        
        val buffer = ByteArray(2048) // Standard MTU size
        
        while (isRunning) {
            try {
                val length = inputStream?.read(buffer) ?: -1
                
                if (length == -1) {
                    Log.w(TAG, "⚠️  TUN interface closed")
                    break
                }
                
                if (length > 0) {
                    packetsRead++
                    bytesRead += length
                    
                    // Extract packet
                    val packet = buffer.copyOf(length)
                    
                    // Log every 100 packets to avoid spam
                    if (packetsRead % 100 == 0L) {
                        Log.d(TAG, "📤 Read packet #$packetsRead (${packet.size} bytes) from TUN")
                        printPacketStats()
                    }
                    
                    // Send packet via HTTP tunnel
                    httpTunnelHandler.sendPacket(packet)
                }
                
            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "❌ Error reading from TUN", e)
                    delay(100) // Backoff on error
                }
            }
        }
        
        Log.d(TAG, "📖 Packet reader stopped")
    }
    
    /**
     * Receive packets from HTTP tunnel and write to TUN interface
     */
    private suspend fun receivePacketsFromTunnel() {
        Log.d(TAG, "📝 Starting packet writer thread...")
        
        while (isRunning) {
            try {
                // Poll for packets from HTTP tunnel
                val packets = httpTunnelHandler.receivePackets()
                
                if (packets.isNotEmpty()) {
                    for (packet in packets) {
                        writePacketToTun(packet)
                    }
                } else {
                    // No packets available, wait a bit
                    delay(10)
                }
                
            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "❌ Error receiving from tunnel", e)
                    delay(100) // Backoff on error
                }
            }
        }
        
        Log.d(TAG, "📝 Packet writer stopped")
    }
    
    /**
     * Write packet to TUN interface
     */
    private fun writePacketToTun(packet: ByteArray) {
        try {
            outputStream?.write(packet)
            outputStream?.flush()
            
            packetsWritten++
            bytesWritten += packet.size
            
            // Log every 100 packets to avoid spam
            if (packetsWritten % 100 == 0L) {
                Log.d(TAG, "📥 Wrote packet #$packetsWritten (${packet.size} bytes) to TUN")
                printPacketStats()
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing to TUN", e)
        }
    }
    
    /**
     * Print statistics
     */
    private fun printPacketStats() {
        Log.d(TAG, "📊 Statistics:")
        Log.d(TAG, "   Packets read:    $packetsRead (${formatBytes(bytesRead)})")
        Log.d(TAG, "   Packets written: $packetsWritten (${formatBytes(bytesWritten)})")
    }
    
    /**
     * Stop intercepting packets
     */
    fun stop() {
        Log.d(TAG, "🛑 Stopping TUN packet interceptor...")
        
        isRunning = false
        
        try {
            inputStream?.close()
            outputStream?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing streams", e)
        }
        
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "📊 Final Statistics:")
        Log.d(TAG, "   Total packets read:    $packetsRead (${formatBytes(bytesRead)})")
        Log.d(TAG, "   Total packets written: $packetsWritten (${formatBytes(bytesWritten)})")
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "✅ TUN packet interceptor stopped")
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