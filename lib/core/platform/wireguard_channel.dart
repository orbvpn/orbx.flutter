import 'package:flutter/services.dart';
import '../../data/models/wireguard_config.dart';

class WireGuardChannel {
  static const MethodChannel _channel = MethodChannel('com.orbvpn.orbx/vpn');

  // Generate WireGuard keypair (uses native crypto)
  static Future<Map<String, String>> generateKeypair() async {
    try {
      final result = await _channel.invokeMethod('generateKeypair');
      return {
        'privateKey': result['privateKey'] as String,
        'publicKey': result['publicKey'] as String,
      };
    } catch (e) {
      throw Exception('Failed to generate keypair: $e');
    }
  }

  // Connect to WireGuard tunnel
  // ✅ FIXED: Now includes protocol and authToken
  static Future<bool> connect(WireGuardConfig config) async {
    try {
      print('🔵 WireGuardChannel: Sending connect request to native');
      print('   Config details:');
      print('   - serverEndpoint: ${config.serverEndpoint}');
      print('   - allocatedIp: ${config.allocatedIp}');
      print('   - dns: ${config.dns}');
      print('   - mtu: ${config.mtu}');

      final result = await _channel.invokeMethod('connect', {
        'configFile': config.toConfigFile(),
        'privateKey': config.privateKey,
        'serverPublicKey': config.serverPublicKey,
        'serverEndpoint': config.serverEndpoint,
        'allocatedIp': config.allocatedIp,
        'dns': config.dns,
        'mtu': config.mtu,
        // ✅ ADD THESE TWO FIELDS - they're required by Android OrbVpnService
        'protocol': config.protocol ?? 'http', // Default to 'http' if not set
        'authToken': config.authToken ?? '', // Default to empty if not set
      });

      print('🔵 WireGuardChannel: Native returned: $result');
      return result as bool;
    } catch (e) {
      print('❌ WireGuardChannel: Connect failed: $e');
      throw Exception('Failed to connect: $e');
    }
  }

  // Disconnect VPN
  static Future<bool> disconnect() async {
    try {
      final result = await _channel.invokeMethod('disconnect');
      return result as bool;
    } catch (e) {
      throw Exception('Failed to disconnect: $e');
    }
  }

  // Get connection status
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Failed to get status: $e');
    }
  }

  // Get statistics (bytes sent/received)
  static Future<Map<String, int>> getStatistics() async {
    try {
      final result = await _channel.invokeMethod('getStatistics');
      return {
        'bytesSent': result['bytesSent'] as int,
        'bytesReceived': result['bytesReceived'] as int,
      };
    } catch (e) {
      throw Exception('Failed to get statistics: $e');
    }
  }

  // ✅ FIXED: Listen to connection state changes
  // Now handles both String and Map formats from native code
  static Stream<String> get connectionStateStream {
    return const EventChannel(
      'com.orbvpn.orbx/vpn_state',
    ).receiveBroadcastStream().map((event) {
      // Handle both String and Map formats from Android
      if (event is String) {
        return event;
      } else if (event is Map) {
        // Android sends: mapOf("state" to "connected")
        return event['state'] as String? ?? 'unknown';
      } else {
        // Fallback for unexpected formats
        return 'unknown';
      }
    });
  }
}
