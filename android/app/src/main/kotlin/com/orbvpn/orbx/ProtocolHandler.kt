package com.orbvpn.orbx

import android.content.Context
import android.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * Protocol Mimicry Handler
 * 
 * Tests which protocol WRAPPER (disguise) works best.
 * The actual VPN protocol (WireGuard/VLESS/etc) runs INSIDE the wrapper.
 */
class ProtocolHandler(private val context: Context) {
    
    private val TAG = "ProtocolHandler"
    
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .build()
    
    /**
     * Protocol wrappers (disguises for VPN traffic)
     */
    enum class MimicryProtocol(
        val protocolName: String,
        val endpoint: String,
        val userAgent: String,
        val regions: List<String>
    ) {
        TEAMS("Microsoft Teams", "/teams/messages", 
              "Mozilla/5.0 Teams/1.5.00.32283", listOf("*")),
        
        SHAPARAK("Shaparak Banking", "/shaparak/transaction",
                 "ShaparakClient/2.0", listOf("IR")),
        
        DOH("DNS over HTTPS", "/dns-query",
            "Mozilla/5.0", listOf("*")),
        
        GOOGLE("Google Workspace", "/google/",
               "Mozilla/5.0 Chrome/120.0.0.0", listOf("*")),
        
        ZOOM("Zoom", "/zoom/",
             "Mozilla/5.0 Zoom/5.16.0", listOf("*")),
        
        FACETIME("FaceTime", "/facetime/",
                 "FaceTime/1.0 CFNetwork/1404.0.5", listOf("*")),
        
        VK("VK", "/vk/",
           "VKAndroidApp/7.26", listOf("RU", "BY", "KZ", "UA")),
        
        YANDEX("Yandex", "/yandex/",
               "Mozilla/5.0 YaBrowser/23.11.0", listOf("RU", "BY", "KZ")),
        
        WECHAT("WeChat", "/wechat/",
               "MicroMessenger/8.0.37", listOf("CN", "HK", "TW")),
        
        HTTPS("HTTPS", "/",
              "Mozilla/5.0 Chrome/120.0.0.0", listOf("*"))
    }
    
    /**
     * VPN protocols that can run inside the wrapper
     */
    enum class VPNProtocol {
        WIREGUARD,  // Current implementation
        VLESS,      // Future
        CISCO,      // Future
        OPENVPN     // Future
    }
    
    data class ProtocolTestResult(
        val protocol: MimicryProtocol,
        val isReachable: Boolean,
        val canSurfWeb: Boolean,  // NEW: Actually test if internet works
        val latencyMs: Long,
        val errorMessage: String? = null
    )
    
    /**
     * Test if a mimicry protocol wrapper is accessible
     */
    fun testProtocolReachability(
        serverAddress: String,
        protocol: MimicryProtocol,
        authToken: String
    ): ProtocolTestResult {
        return try {
            Log.d(TAG, "Testing reachability: ${protocol.protocolName}")
            
            val startTime = System.currentTimeMillis()
            val url = "https://$serverAddress:443${protocol.endpoint}"
            
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", protocol.userAgent)
                .header("Authorization", "Bearer $authToken")
                .get()
                .build()
            
            val response = httpClient.newCall(request).execute()
            val latency = System.currentTimeMillis() - startTime
            
            // Server responded = wrapper is reachable
            val isReachable = response.isSuccessful || response.code == 401
            response.close()
            
            Log.d(TAG, "${protocol.protocolName}: Reachable=$isReachable (${latency}ms)")
            
            ProtocolTestResult(
                protocol = protocol,
                isReachable = isReachable,
                canSurfWeb = false, // Will be tested separately after VPN connects
                latencyMs = latency
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reach ${protocol.protocolName}", e)
            ProtocolTestResult(protocol, false, false, -1, e.message)
        }
    }
    
    /**
     * Test if we can actually browse the web through this protocol
     * This is called AFTER VPN is connected
     */
    fun testInternetConnectivity(protocol: MimicryProtocol): Boolean {
        return try {
            Log.d(TAG, "Testing internet through ${protocol.protocolName}")
            
            // Try to reach a reliable external site
            val testUrls = listOf(
                "https://www.google.com/generate_204",  // Returns 204 if working
                "https://cloudflare.com/cdn-cgi/trace", // Cloudflare test
                "https://1.1.1.1"                        // Cloudflare DNS
            )
            
            for (testUrl in testUrls) {
                try {
                    val request = Request.Builder()
                        .url(testUrl)
                        .get()
                        .build()
                    
                    val response = httpClient.newCall(request).execute()
                    val success = response.isSuccessful
                    response.close()
                    
                    if (success) {
                        Log.d(TAG, "✅ Internet works through ${protocol.protocolName}")
                        return true
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "Test URL $testUrl failed: ${e.message}")
                    continue
                }
            }
            
            Log.w(TAG, "❌ Internet NOT working through ${protocol.protocolName}")
            return false
            
        } catch (e: Exception) {
            Log.e(TAG, "Internet test failed for ${protocol.protocolName}", e)
            return false
        }
    }
    
    /**
     * Find best working protocol with internet verification
     */
    fun findBestWorkingProtocol(
        serverAddress: String,
        authToken: String,
        userRegion: String?,
        onProtocolTested: (MimicryProtocol, Boolean) -> Unit
    ): MimicryProtocol? {
        Log.d(TAG, "Finding best working protocol for region: $userRegion")
        
        // Get protocols sorted by preference for this region
        val protocolsToTest = if (userRegion != null) {
            MimicryProtocol.values().sortedByDescending { protocol ->
                when {
                    protocol.regions.contains(userRegion) -> 2  // Perfect match
                    protocol.regions.contains("*") -> 1         // Universal
                    else -> 0                                    // Not recommended
                }
            }
        } else {
            MimicryProtocol.values().toList()
        }
        
        // Test each protocol
        for (protocol in protocolsToTest) {
            Log.d(TAG, "Testing protocol: ${protocol.protocolName}")
            
            // Step 1: Test if we can reach the server with this wrapper
            val reachability = testProtocolReachability(serverAddress, protocol, authToken)
            
            if (!reachability.isReachable) {
                Log.d(TAG, "❌ ${protocol.protocolName} not reachable")
                onProtocolTested(protocol, false)
                continue
            }
            
            Log.d(TAG, "✅ ${protocol.protocolName} is reachable")
            
            // Step 2: This would be tested AFTER VPN connects
            // For now, we just return the first reachable protocol
            // The actual internet test happens in the connection flow
            onProtocolTested(protocol, true)
            return protocol
        }
        
        Log.w(TAG, "No working protocols found")
        return null
    }
    
    fun getProtocolByName(name: String): MimicryProtocol? {
        return try {
            MimicryProtocol.valueOf(name.uppercase())
        } catch (e: Exception) {
            null
        }
    }
}