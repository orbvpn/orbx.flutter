package com.orbvpn.orbx\n\nclass MainActivity {}\n

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.orbvpn.orbx/wireguard"
    private val EVENT_CHANNEL = "com.orbvpn.orbx/wireguard_state"
    private val VPN_REQUEST_CODE = 1001

    private lateinit var wireguardManager: WireGuardManager
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        wireguardManager = WireGuardManager(applicationContext)

        // Method Channel (for function calls)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "generateKeypair" -> {
                    val keypair = wireguardManager.generateKeypair()
                    result.success(keypair)
                }

                "connect" -> {
                    // Request VPN permission first
                    val intent = VpnService.prepare(applicationContext)
                    if (intent != null) {
                        pendingResult = result
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        // Permission already granted
                        val config = call.arguments as Map<String, Any>
                        val success = wireguardManager.connect(config)
                        
                        if (success) {
                            // Start foreground service
                            val serviceIntent = Intent(
                                this,
                                OrbVpnService::class.java
                            ).apply {
                                action = OrbVpnService.ACTION_CONNECT
                            }
                            startForegroundService(serviceIntent)
                        }
                        
                        result.success(success)
                    }
                }

                "disconnect" -> {
                    val success = wireguardManager.disconnect()
                    
                    // Stop foreground service
                    val serviceIntent = Intent(this, OrbVpnService::class.java)
                    stopService(serviceIntent)
                    
                    result.success(success)
                }

                "getStatus" -> {
                    val status = wireguardManager.getStatus()
                    result.success(status)
                }

                "getStatistics" -> {
                    val stats = wireguardManager.getStatistics()
                    result.success(stats)
                }

                else -> result.notImplemented()
            }
        }

        // Event Channel (for state changes)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                // TODO: Implement state change listener
            }

            override fun onCancel(arguments: Any?) {
                // Cleanup
            }
        })
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                // Permission granted, connect
                pendingResult?.success(true)
            } else {
                // Permission denied
                pendingResult?.error(
                    "VPN_PERMISSION_DENIED",
                    "User denied VPN permission",
                    null
                )
            }
            pendingResult = null
        }
    }
}