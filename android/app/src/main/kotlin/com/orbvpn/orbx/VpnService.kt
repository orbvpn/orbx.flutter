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

class OrbVpnService : VpnService() {
    private val TAG = "OrbVpnService"
    private var vpnInterface: ParcelFileDescriptor? = null
    
    companion object {
        const val ACTION_CONNECT = "com.orbvpn.orbx.CONNECT"
        const val ACTION_DISCONNECT = "com.orbvpn.orbx.DISCONNECT"
        const val NOTIFICATION_CHANNEL_ID = "OrbVPN_Channel"
        const val NOTIFICATION_ID = 1
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                Log.d(TAG, "Starting VPN connection")
                startForeground(NOTIFICATION_ID, createNotification())
                // Connection is handled by WireGuard backend
            }
            ACTION_DISCONNECT -> {
                Log.d(TAG, "Stopping VPN connection")
                stopVpn()
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun stopVpn() {
        try {
            vpnInterface?.close()
            vpnInterface = null
            Log.d(TAG, "VPN interface closed")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping VPN", e)
        }
    }

    private fun createNotification(): Notification {
        createNotificationChannel()

        val disconnectIntent = Intent(this, OrbVpnService::class.java).apply {
            action = ACTION_DISCONNECT
        }
        val disconnectPendingIntent = PendingIntent.getService(
            this, 0, disconnectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("OrbVPN Connected")
            .setContentText("Your connection is secure")
            .setSmallIcon(R.drawable.ic_vpn)
            .addAction(
                R.drawable.ic_disconnect,
                "Disconnect",
                disconnectPendingIntent
            )
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "OrbVPN Connection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows VPN connection status"
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVpn()
    }
}