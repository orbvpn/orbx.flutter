package com.orbvpn.orbx

import android.content.Context
import android.util.Base64
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.TimeUnit

/**
 * HttpTunnelHandler
 * 
 * Sends VPN packets via HTTPS POST requests disguised as legitimate app traffic
 * Supports multiple protocol mimicry modes: Teams, Google, Shaparak, etc.
 */
class HttpTunnelHandler(
    private val serverAddress: String,
    private val authToken: String,
    private val protocol: String,
    private val context: Context
) {
    private val TAG = "HttpTunnelHandler"
    
    private val client: OkHttpClient
    private val responseQueue = ConcurrentLinkedQueue<ByteArray>()
    
    // Statistics
    private var packetsSent = 0L
    private var packetsReceived = 0L
    private var bytesSent = 0L
    private var bytesReceived = 0L
    
    init {
        Log.d(TAG, "🔧 Initializing HTTP tunnel handler...")
        Log.d(TAG, "   Server: $serverAddress")
        Log.d(TAG, "   Protocol: $protocol")
        
        // Configure OkHttp client
        client = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .writeTimeout(10, TimeUnit.SECONDS)
            // ⚠️  DEVELOPMENT ONLY: Accept self-signed certificates
            .hostnameVerifier { _, _ -> true }
            .build()
        
        Log.d(TAG, "✅ HTTP tunnel handler initialized")
    }
    
    /**
     * Send a packet via HTTPS (protocol mimicry)
     */
    suspend fun sendPacket(packet: ByteArray) {
        withContext(Dispatchers.IO) {
            try {
                val endpoint = getProtocolEndpoint()
                val url = "https://$serverAddress:8443$endpoint"
                
                // Encode packet as base64
                val encodedPacket = Base64.encodeToString(packet, Base64.NO_WRAP)
                
                // Create protocol-specific payload
                val payload = createProtocolPayload(encodedPacket)
                
                // Create protocol-specific headers
                val headers = createProtocolHeaders()
                
                // Build request
                val requestBody = payload.toString()
                    .toRequestBody("application/json; charset=utf-8".toMediaType())
                
                val request = Request.Builder()
                    .url(url)
                    .post(requestBody)
                    .apply {
                        // Add protocol-specific headers
                        headers.forEach { (key, value) ->
                            addHeader(key, value)
                        }
                    }
                    .build()
                
                // Send request
                val response = client.newCall(request).execute()
                
                if (response.isSuccessful) {
                    // Parse response
                    val responseBody = response.body?.string()
                    if (responseBody != null) {
                        val responseJson = JSONObject(responseBody)
                        val encodedResponse = responseJson.optString("content", "")
                        
                        if (encodedResponse.isNotEmpty()) {
                            val decodedResponse = Base64.decode(encodedResponse, Base64.NO_WRAP)
                            responseQueue.offer(decodedResponse)
                            
                            packetsReceived++
                            bytesReceived += decodedResponse.size
                        }
                    }
                    
                    packetsSent++
                    bytesSent += packet.size
                    
                } else {
                    Log.w(TAG, "⚠️  HTTP request failed: ${response.code}")
                }
                
                response.close()
                
            } catch (e: IOException) {
                Log.e(TAG, "❌ Network error sending packet", e)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error sending packet", e)
            }
        }
    }
    
    /**
     * Receive packets from HTTP tunnel
     * Returns list of packets received since last call
     */
    suspend fun receivePackets(): List<ByteArray> {
        return withContext(Dispatchers.IO) {
            val packets = mutableListOf<ByteArray>()
            
            // Drain response queue
            while (responseQueue.isNotEmpty()) {
                responseQueue.poll()?.let { packets.add(it) }
            }
            
            packets
        }
    }
    
    /**
     * Get protocol-specific endpoint
     */
    private fun getProtocolEndpoint(): String {
        return when (protocol.lowercase()) {
            "teams" -> "/teams/messages"
            "google" -> "/google/drive/files"
            "shaparak" -> "/shaparak/transaction"
            "doh" -> "/dns-query"
            "https" -> "/api/v1/sync"
            "zoom" -> "/zoom/rtc"
            "facetime" -> "/facetime/call"
            "vk" -> "/vk/api"
            "yandex" -> "/yandex/disk"
            else -> "/https/request"
        }
    }
    
    /**
     * Create protocol-specific payload
     */
    private fun createProtocolPayload(encodedPacket: String): JSONObject {
        val json = JSONObject()
        
        when (protocol.lowercase()) {
            "teams" -> {
                json.put("type", "message")
                json.put("content", encodedPacket)
                json.put("messageId", UUID.randomUUID().toString())
                json.put("timestamp", System.currentTimeMillis())
                json.put("channelId", "19:meeting_${UUID.randomUUID()}")
            }
            
            "google" -> {
                json.put("kind", "drive#file")
                json.put("name", "sync_${System.currentTimeMillis()}.dat")
                json.put("mimeType", "application/octet-stream")
                json.put("content", encodedPacket)
            }
            
            "shaparak" -> {
                // Iranian banking protocol (SOAP-like)
                json.put("Amount", "50000")
                json.put("MerchantID", "123456")
                json.put("Data", encodedPacket)
                json.put("TerminalID", "98765")
            }
            
            "doh" -> {
                json.put("type", "A")
                json.put("name", "example.com")
                json.put("data", encodedPacket)
            }
            
            "zoom" -> {
                json.put("stream", encodedPacket)
                json.put("meetingId", "123456789")
                json.put("participantId", UUID.randomUUID().toString())
            }
            
            else -> {
                json.put("data", encodedPacket)
                json.put("timestamp", System.currentTimeMillis())
            }
        }
        
        return json
    }
    
    /**
     * Create protocol-specific headers
     */
    private fun createProtocolHeaders(): Map<String, String> {
        val headers = mutableMapOf(
            "Authorization" to "Bearer $authToken",
            "Content-Type" to "application/json",
            "Accept" to "application/json"
        )
        
        when (protocol.lowercase()) {
            "teams" -> {
                headers["User-Agent"] = "Microsoft Teams/1.5.00.32283"
                headers["X-Ms-Client-Version"] = "1.5.00.32283"
                headers["X-Ms-Session-Id"] = UUID.randomUUID().toString()
                headers["MS-CV"] = UUID.randomUUID().toString()
            }
            
            "google" -> {
                headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0"
                headers["X-Goog-Api-Client"] = "gl-android/30 gdrive/2.21.234"
                headers["X-Goog-Request-Id"] = UUID.randomUUID().toString()
            }
            
            "shaparak" -> {
                headers["Content-Type"] = "text/xml; charset=utf-8"
                headers["SOAPAction"] = "ProcessTransaction"
                headers["User-Agent"] = "ShaparakClient/2.0"
            }
            
            "doh" -> {
                headers["Content-Type"] = "application/dns-message"
                headers["Accept"] = "application/dns-message"
            }
            
            "zoom" -> {
                headers["User-Agent"] = "zoom.us/5.13.0"
                headers["X-Zoom-Session"] = UUID.randomUUID().toString()
            }
            
            else -> {
                headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
            }
        }
        
        return headers
    }
    
    /**
     * Print statistics
     */
    fun printStatistics() {
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "📊 HTTP Tunnel Statistics ($protocol)")
        Log.d(TAG, "   Packets sent:     $packetsSent (${formatBytes(bytesSent)})")
        Log.d(TAG, "   Packets received: $packetsReceived (${formatBytes(bytesReceived)})")
        Log.d(TAG, "═══════════════════════════════════════")
    }
    
    /**
     * Cleanup
     */
    fun stop() {
        printStatistics()
        // OkHttp will be garbage collected
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