// lib/core/services/http_tunnel_service.dart
// HTTP Tunnel Service - Wraps VPN packets in HTTPS requests

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:orbx/core/config/environment_config.dart';

/// HTTP Tunnel Service
///
/// Captures WireGuard packets and tunnels them through HTTPS POST requests
/// disguised as Microsoft Teams or Google Workspace traffic
class HttpTunnelService {
  final Dio _dio;
  final String _serverAddress;
  final String _authToken;
  final String _protocol;

  // Packet batching
  final List<Uint8List> _packetQueue = [];
  Timer? _batchTimer;
  final int _maxBatchSize = 10;
  final Duration _batchInterval = const Duration(milliseconds: 50);

  // Statistics
  int _packetsSent = 0;
  int _packetsReceived = 0;
  int _bytesSent = 0;
  int _bytesReceived = 0;
  int _sequenceNumber = 0;

  HttpTunnelService({
    required String serverAddress,
    required String authToken,
    required String protocol, // 'teams', 'google', 'shaparak', etc.
  })  : _serverAddress = serverAddress,
        _authToken = authToken,
        _protocol = protocol,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status != null && status < 500,
        ));

  /// Start the HTTP tunnel
  Future<void> start() async {
    print('🚀 Starting HTTP tunnel with $_protocol protocol');
    _startBatchTimer();
  }

  /// Stop the HTTP tunnel
  Future<void> stop() async {
    print('🛑 Stopping HTTP tunnel');
    _batchTimer?.cancel();
    await _flushQueue();
  }

  /// Send a packet through the HTTPS tunnel
  Future<List<Uint8List>> sendPacket(Uint8List packet) async {
    _packetQueue.add(packet);

    // If queue is full, flush immediately
    if (_packetQueue.length >= _maxBatchSize) {
      return await _flushQueue();
    }

    return [];
  }

  /// Start batch timer
  void _startBatchTimer() {
    _batchTimer = Timer.periodic(_batchInterval, (timer) {
      if (_packetQueue.isNotEmpty) {
        _flushQueue();
      }
    });
  }

  /// Flush packet queue - send batched packets
  Future<List<Uint8List>> _flushQueue() async {
    if (_packetQueue.isEmpty) return [];

    final packetsToSend = List<Uint8List>.from(_packetQueue);
    _packetQueue.clear();

    try {
      // Combine packets for batching (optional optimization)
      final responses = <Uint8List>[];

      for (final packet in packetsToSend) {
        final response = await _sendSinglePacket(packet);
        if (response != null) {
          responses.add(response);
        }
      }

      return responses;
    } catch (e) {
      print('❌ Error flushing packet queue: $e');
      return [];
    }
  }

  /// Send a single packet through HTTPS
  Future<Uint8List?> _sendSinglePacket(Uint8List packet) async {
    try {
      _sequenceNumber++;
      _packetsSent++;
      _bytesSent += packet.length;

      // Choose endpoint based on protocol
      final endpoint = _getProtocolEndpoint();
      final url = 'https://$_serverAddress:8443$endpoint';

      // Encode packet as base64
      final encodedPacket = base64.encode(packet);

      // Create protocol-specific payload
      final payload = _createProtocolPayload(encodedPacket);

      // Create protocol-specific headers
      final headers = _createProtocolHeaders();

      if (EnvironmentConfig.enableDebugLogging) {
        print(
            '📤 Sending packet #$_sequenceNumber (${packet.length} bytes) via $_protocol');
      }

      // Send HTTPS POST request
      final response = await _dio.post(
        url,
        data: jsonEncode(payload),
        options: Options(
          headers: headers,
          validateStatus: (status) => status == 200,
        ),
      );

      if (response.statusCode == 200) {
        // Parse response
        final responseData = response.data as Map<String, dynamic>;
        final encodedResponse = responseData['content'] as String;
        final decodedResponse = base64.decode(encodedResponse);

        _packetsReceived++;
        _bytesReceived += decodedResponse.length;

        if (EnvironmentConfig.enableDebugLogging) {
          print('📥 Received response (${decodedResponse.length} bytes)');
        }

        return Uint8List.fromList(decodedResponse);
      } else {
        print('⚠️  Unexpected response: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error sending packet: $e');
      return null;
    }
  }

  /// Get endpoint based on protocol
  String _getProtocolEndpoint() {
    switch (_protocol) {
      case 'teams':
        return '/teams/messages';
      case 'google':
        return '/google/drive/files';
      case 'shaparak':
        return '/shaparak/transaction';
      case 'doh':
        return '/dns-query';
      default:
        return '/teams/messages';
    }
  }

  /// Create protocol-specific payload
  Map<String, dynamic> _createProtocolPayload(String encodedPacket) {
    switch (_protocol) {
      case 'teams':
        return {
          'type': 'message',
          'content': encodedPacket,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'clientId': 'orbx-client-${DateTime.now().millisecondsSinceEpoch}',
          'sequence': _sequenceNumber,
        };

      case 'google':
        return {
          'kind': 'drive#file',
          'data': encodedPacket,
          'timestamp': DateTime.now().toIso8601String(),
          'requestId': 'req_${DateTime.now().millisecondsSinceEpoch}',
        };

      case 'shaparak':
        // Shaparak uses XML, but we'll keep JSON for simplicity
        return {
          'transactionType': 'payment',
          'amount': '50000',
          'merchantId': '123456',
          'data': encodedPacket,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

      default:
        return {
          'type': 'data',
          'content': encodedPacket,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
    }
  }

  /// Create protocol-specific headers
  Map<String, String> _createProtocolHeaders() {
    final baseHeaders = {
      'Authorization': 'Bearer $_authToken',
      'Content-Type': 'application/json',
    };

    switch (_protocol) {
      case 'teams':
        return {
          ...baseHeaders,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Teams/1.5.00.32283',
          'X-Ms-Client-Version': '27/1.0.0.2024',
          'X-Ms-Session-Id': 'session-${DateTime.now().millisecondsSinceEpoch}',
        };

      case 'google':
        return {
          ...baseHeaders,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0',
          'X-Goog-Api-Client': 'gl-dart/3.0.0 gdcl/1.0.0',
          'X-Goog-Request-Id': 'req-${DateTime.now().millisecondsSinceEpoch}',
        };

      case 'shaparak':
        return {
          ...baseHeaders,
          'User-Agent': 'ShaparakClient/2.0',
          'SOAPAction': 'ProcessTransaction',
        };

      default:
        return {
          ...baseHeaders,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0',
        };
    }
  }

  /// Get tunnel statistics
  Map<String, int> getStatistics() {
    return {
      'packetsSent': _packetsSent,
      'packetsReceived': _packetsReceived,
      'bytesSent': _bytesSent,
      'bytesReceived': _bytesReceived,
    };
  }

  /// Print statistics
  void printStatistics() {
    print('╔════════════════════════════════════════╗');
    print('║   HTTP Tunnel Statistics               ║');
    print('╠════════════════════════════════════════╣');
    print('║ Protocol: $_protocol');
    print('║ Packets Sent: $_packetsSent');
    print('║ Packets Received: $_packetsReceived');
    print('║ Bytes Sent: ${(_bytesSent / 1024).toStringAsFixed(2)} KB');
    print('║ Bytes Received: ${(_bytesReceived / 1024).toStringAsFixed(2)} KB');
    print('╚════════════════════════════════════════╝');
  }
}
