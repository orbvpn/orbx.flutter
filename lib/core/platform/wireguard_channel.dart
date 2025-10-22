import 'package:flutter/services.dart';
import '../../data/models/wireguard_config.dart';

class WireGuardChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.orbvpn.orbx/vpn',
  );

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
  static Future<bool> connect(WireGuardConfig config) async {
    try {
      final result = await _channel.invokeMethod('connect', {
        'configFile': config.toConfigFile(),
        'privateKey': config.privateKey,
        'serverPublicKey': config.serverPublicKey,
        'endpoint': config.serverEndpoint,
        'allocatedIp': config.allocatedIp,
        'dns': config.dns,
        'mtu': config.mtu,
      });
      return result as bool;
    } catch (e) {
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

// Listen to connection state changes
  static Stream<String> get connectionStateStream {
    return const EventChannel(
      'com.orbvpn.orbx/vpn_state',
    ).receiveBroadcastStream().map((event) => event as String);
  }
}
