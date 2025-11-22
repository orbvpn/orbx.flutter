package com.orbvpn.orbx

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * ProtocolManager
 *
 * Manages protocol selection and fallback for DPI evasion
 * Features:
 * - Remembers last successful protocol per user/server
 * - Automatic fallback if current protocol fails
 * - Smart Connect toggle (on/off)
 * - Success rate tracking
 */
class ProtocolManager(private val context: Context) {
    private val TAG = "ProtocolManager"

    private val prefs: SharedPreferences = context.getSharedPreferences(
        "protocol_manager_prefs",
        Context.MODE_PRIVATE
    )

    // Available protocols in priority order (most reliable first)
    private val availableProtocols = listOf(
        Protocol("https", "Generic HTTPS", 100),
        Protocol("teams", "Microsoft Teams", 90),
        Protocol("google", "Google Drive/Meet", 85),
        Protocol("shaparak", "Iranian Banking", 80),
        Protocol("zoom", "Zoom Conference", 75),
        Protocol("doh", "DNS over HTTPS", 70),
        Protocol("facetime", "Apple FaceTime", 65),
        Protocol("yandex", "Yandex Services", 60),
        Protocol("wechat", "WeChat", 55),
        Protocol("vk", "VK Social", 50)
    )

    data class Protocol(
        val id: String,
        val displayName: String,
        val basePriority: Int
    )

    /**
     * Check if Smart Connect is enabled
     */
    fun isSmartConnectEnabled(): Boolean {
        return prefs.getBoolean("smart_connect_enabled", true) // Default: ON
    }

    /**
     * Enable/disable Smart Connect
     */
    fun setSmartConnectEnabled(enabled: Boolean) {
        prefs.edit().putBoolean("smart_connect_enabled", enabled).apply()
        Log.i(TAG, "Smart Connect ${if (enabled) "enabled" else "disabled"}")
    }

    /**
     * Get the best protocol to try for this server
     * Returns last successful protocol if available, otherwise most reliable
     */
    fun getBestProtocol(serverAddress: String): String {
        val lastSuccessful = prefs.getString("last_successful_${serverAddress}", null)

        if (lastSuccessful != null && isProtocolAvailable(lastSuccessful)) {
            Log.i(TAG, "Using last successful protocol for $serverAddress: $lastSuccessful")
            return lastSuccessful
        }

        // No history, use highest priority protocol
        val best = availableProtocols.firstOrNull()?.id ?: "https"
        Log.i(TAG, "No history for $serverAddress, using default: $best")
        return best
    }

    /**
     * Get list of protocols to try in fallback order
     * Starts with last successful, then by priority
     */
    fun getFallbackProtocols(serverAddress: String): List<String> {
        val lastSuccessful = prefs.getString("last_successful_${serverAddress}", null)
        val protocols = mutableListOf<String>()

        // Add last successful first if available
        if (lastSuccessful != null && isProtocolAvailable(lastSuccessful)) {
            protocols.add(lastSuccessful)
        }

        // Add remaining protocols by priority (excluding already added)
        availableProtocols
            .map { it.id }
            .filter { it != lastSuccessful }
            .forEach { protocols.add(it) }

        Log.d(TAG, "Fallback order for $serverAddress: ${protocols.joinToString(", ")}")
        return protocols
    }

    /**
     * Record successful connection with a protocol
     */
    fun recordSuccess(serverAddress: String, protocol: String) {
        prefs.edit()
            .putString("last_successful_${serverAddress}", protocol)
            .putLong("last_success_time_${serverAddress}_${protocol}", System.currentTimeMillis())
            .putInt("success_count_${serverAddress}_${protocol}",
                prefs.getInt("success_count_${serverAddress}_${protocol}", 0) + 1)
            .apply()

        Log.i(TAG, "✅ Recorded successful connection: $serverAddress with $protocol")
        Log.i(TAG, "   This protocol will be tried first next time")
    }

    /**
     * Record failed connection attempt
     */
    fun recordFailure(serverAddress: String, protocol: String) {
        prefs.edit()
            .putLong("last_failure_time_${serverAddress}_${protocol}", System.currentTimeMillis())
            .putInt("failure_count_${serverAddress}_${protocol}",
                prefs.getInt("failure_count_${serverAddress}_${protocol}", 0) + 1)
            .apply()

        Log.w(TAG, "❌ Recorded failed attempt: $serverAddress with $protocol")
    }

    /**
     * Get protocol statistics for debugging
     */
    fun getProtocolStats(serverAddress: String, protocol: String): ProtocolStats {
        return ProtocolStats(
            protocol = protocol,
            successCount = prefs.getInt("success_count_${serverAddress}_${protocol}", 0),
            failureCount = prefs.getInt("failure_count_${serverAddress}_${protocol}", 0),
            lastSuccessTime = prefs.getLong("last_success_time_${serverAddress}_${protocol}", 0),
            lastFailureTime = prefs.getLong("last_failure_time_${serverAddress}_${protocol}", 0)
        )
    }

    data class ProtocolStats(
        val protocol: String,
        val successCount: Int,
        val failureCount: Int,
        val lastSuccessTime: Long,
        val lastFailureTime: Long
    ) {
        val successRate: Float
            get() = if (successCount + failureCount == 0) 0f
                    else successCount.toFloat() / (successCount + failureCount)
    }

    /**
     * Check if protocol is in our available list
     */
    private fun isProtocolAvailable(protocol: String): Boolean {
        return availableProtocols.any { it.id == protocol }
    }

    /**
     * Get all available protocol IDs
     */
    fun getAllProtocolIds(): List<String> {
        return availableProtocols.map { it.id }
    }

    /**
     * Get protocol display name
     */
    fun getProtocolDisplayName(protocol: String): String {
        return availableProtocols.find { it.id == protocol }?.displayName ?: protocol
    }

    /**
     * Clear all stored protocol preferences (for testing/reset)
     */
    fun clearAllStats() {
        prefs.edit().clear().apply()
        Log.i(TAG, "All protocol statistics cleared")
    }

    /**
     * Print statistics for debugging
     */
    fun printStats(serverAddress: String) {
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "Protocol Statistics for: $serverAddress")
        Log.d(TAG, "═══════════════════════════════════════")

        val lastSuccessful = prefs.getString("last_successful_${serverAddress}", "none")
        Log.d(TAG, "Last Successful: $lastSuccessful")
        Log.d(TAG, "Smart Connect: ${if (isSmartConnectEnabled()) "ON" else "OFF"}")
        Log.d(TAG, "")

        availableProtocols.forEach { proto ->
            val stats = getProtocolStats(serverAddress, proto.id)
            if (stats.successCount > 0 || stats.failureCount > 0) {
                Log.d(TAG, "${proto.displayName} (${proto.id}):")
                Log.d(TAG, "  Success: ${stats.successCount}, Failures: ${stats.failureCount}")
                Log.d(TAG, "  Success Rate: ${(stats.successRate * 100).toInt()}%")
            }
        }

        Log.d(TAG, "═══════════════════════════════════════")
    }
}
