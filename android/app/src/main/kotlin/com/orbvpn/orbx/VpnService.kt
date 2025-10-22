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
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import kotlinx.coroutines.*

class OrbVpnService : VpnService() {
    private val TAG = "OrbVpnService"
    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Notification
    private val CHANNEL_ID = "OrbVPN_Channel"
    private val NOTIFICATION_ID = 1
    
    // Statistics
    private var bytesSent: Long = 0
    private var bytesReceived: Long = 0
    
    companion object {
        const val ACTION_CONNECT = "com.orbvpn.orbx.CONNECT"
        const val ACTION_DISCONNECT = "com.orbvpn.orbx.DISCONNECT"
        const val EXTRA_CONFIG = "config"
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "VPN Service created")
        createNotificationChannel()
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
                
                // Build VPN interface
                val builder = Builder()
                    .setSession("OrbVPN")
                    .addAddress("10.8.0.2", 24)
                    .addRoute("0.0.0.0", 0)
                    .addDnsServer("1.1.1.1")
                    .addDnsServer("8.8.8.8")
                    .setMtu(1400)
                
                // Establish VPN
                vpnInterface = builder.establish()
                
                if (vpnInterface == null) {
                    Log.e(TAG, "Failed to establish VPN interface")
                    updateNotification("Connection failed")
                    stopSelf()
                    return@launch
                }
                
                isRunning = true
                updateNotification("Connected")
                Log.d(TAG, "VPN connected successfully")
                
                // Start packet forwarding
                startPacketForwarding(config)
                
            } catch (e: Exception) {
                Log.e(TAG, "VPN connection failed", e)
                updateNotification("Connection failed: ${e.message}")
                stopSelf()
            }
        }
    }
    
    private fun disconnect() {
        Log.d(TAG, "Disconnecting VPN...")
        
        isRunning = false
        
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
            Log.e(TAG, "Error closing VPN interface", e)
        }
        
        scope.cancel()
        stopForeground(true)
        stopSelf()
        
        Log.d(TAG, "VPN disconnected")
    }
    
    private fun startPacketForwarding(config: Map<String, Any>) {
        scope.launch {
            val inputStream = FileInputStream(vpnInterface!!.fileDescriptor)
            val outputStream = FileOutputStream(vpnInterface!!.fileDescriptor)
            val buffer = ByteBuffer.allocate(32767)
            
            try {
                while (isRunning) {
                    // Read from VPN interface
                    val length = inputStream.channel.read(buffer)
                    
                    if (length > 0) {
                        buffer.flip()
                        
                        // Process packet (this is simplified - real implementation would use WireGuard)
                        val packet = ByteArray(length)
                        buffer.get(packet)
                        
                        // Update statistics
                        bytesSent += length
                        
                        // Write back (echo for now - real implementation would encrypt and send to server)
                        buffer.clear()
                        buffer.put(packet)
                        buffer.flip()
                        outputStream.channel.write(buffer)
                        
                        bytesReceived += length
                        buffer.clear()
                    }
                    
                    delay(10) // Small delay to prevent busy loop
                }
            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "Packet forwarding error", e)
                }
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
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(status: String): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("OrbVPN")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun updateNotification(status: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, createNotification(status))
    }
    
    fun getStatistics(): Map<String, Long> {
        return mapOf(
            "bytesSent" to bytesSent,
            "bytesReceived" to bytesReceived
        )
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "VPN Service destroyed")
        disconnect()
    }
}