import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:orbx/core/config/environment_config.dart';
import 'package:orbx/data/models/server.dart';
import 'package:orbx/data/models/wireguard_config.dart';
import 'package:orbx/core/platform/wireguard_channel.dart';
import 'package:orbx/core/services/http_tunnel_service.dart';

class WireGuardService {
  final Dio _dio;
  bool _isConnected = false;
  WireGuardConfig? _currentConfig;
  OrbXServer? _connectedServer;
  HttpTunnelService? _httpTunnel;

  WireGuardService() : _dio = _createDioClient();

  static Dio _createDioClient() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // ✅ CRITICAL: Accept self-signed certificates for development
    // Remove this in production or implement proper certificate pinning
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
        (client) {
      client.badCertificateCallback = (cert, host, port) {
        print('⚠️  Accepting certificate for $host:$port');
        return true; // Accept all certificates
      };
      return client;
    };

    return dio;
  }

  bool get isConnected => _isConnected;
  WireGuardConfig? get currentConfig => _currentConfig;
  OrbXServer? get connectedServer => _connectedServer;

  /// Connect to VPN with HTTP tunneling
  Future<WireGuardConfig> connect({
    required OrbXServer server,
    required String authToken,
    required String publicKey,
    required String privateKey,
    required String protocol,
  }) async {
    try {
      print('╔════════════════════════════════════════╗');
      print('║   Starting VPN Connection              ║');
      print('╠════════════════════════════════════════╣');
      print('║ Server: ${server.name}');
      print('║ Protocol: $protocol');
      print('║ Region: ${server.region ?? server.location}');
      print('╚════════════════════════════════════════╝');

      final endpoint = server.endpoint;

      // 1. Validate auth token
      if (authToken.isEmpty) {
        throw Exception('Authentication token is empty');
      }

      print('🔑 Auth token length: ${authToken.length}');
      print(
          '🔑 Auth token prefix: ${authToken.substring(0, authToken.length > 20 ? 20 : authToken.length)}...');

      // 2. Generate WireGuard keypair (already done)
      print('🔑 Using provided keypair');
      print('   Public key: ${publicKey.substring(0, 20)}...');

      // 3. Register with server
      print('📞 Connecting to server...');
      print('   Endpoint: https://$endpoint:8443/wireguard/connect');

      final response = await _dio.post(
        'https://$endpoint:8443/wireguard/connect',
        data: {'publicKey': publicKey},
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) {
            // Log the status code
            print('📬 Server response status: $status');
            return status == 200;
          },
        ),
      );

      print('✅ Connection request successful');

      final data = response.data as Map<String, dynamic>;

      if (data['success'] != true) {
        throw Exception(
            'Connection failed: ${data['message'] ?? 'Unknown error'}');
      }

      // 4. Build WireGuard configuration
      print('⚙️  Building WireGuard configuration...');

      final config = WireGuardConfig(
        privateKey: privateKey,
        publicKey: publicKey,
        serverPublicKey: data['serverPublicKey'] as String? ?? '',
        allocatedIp: data['ip'] as String,
        gateway: data['gateway'] as String,
        dns: List<String>.from(data['dns'] as List),
        mtu: data['mtu'] as int,
        serverEndpoint: '$endpoint:51820',
        protocol: protocol,
        authToken: authToken,
      );

      if (EnvironmentConfig.enableDebugLogging) {
        print('   Allocated IP: ${config.allocatedIp}');
        print('   Gateway: ${config.gateway}');
        print('   DNS: ${config.dns.join(", ")}');
        print('   MTU: ${config.mtu}');
        print('   Endpoint: ${config.serverEndpoint}');
      }

      // 5. Establish WireGuard tunnel
      print('🔌 Establishing WireGuard tunnel...');
      final success = await WireGuardChannel.connect(config);

      if (!success) {
        throw Exception('Failed to establish WireGuard tunnel');
      }

      _currentConfig = config;
      _isConnected = true;
      _connectedServer = server;

      // 6. START HTTP TUNNEL FOR MIMICRY
      print('🎭 Starting HTTP tunnel with $protocol mimicry...');
      _httpTunnel = HttpTunnelService(
        serverAddress: endpoint,
        authToken: authToken,
        protocol: protocol,
      );

      await _httpTunnel!.start();

      print('╔════════════════════════════════════════╗');
      print('║   ✅ Connection Established!           ║');
      print('║   🎭 Traffic disguised as $protocol    ║');
      print('╚════════════════════════════════════════╝');

      return config;
    } on DioException catch (e) {
      print('❌ Dio error type: ${e.type}');
      print('❌ Dio error message: ${e.message}');
      print('❌ Response data: ${e.response?.data}');
      print('❌ Response status: ${e.response?.statusCode}');

      if (e.type == DioExceptionType.badCertificate) {
        print('   SSL certificate validation failed');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        print('   Connection timeout');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        print('   Receive timeout');
      } else if (e.type == DioExceptionType.connectionError) {
        print('   Connection error - check network');
      }

      throw Exception('Connection failed: ${e.message}');
    } catch (e, stackTrace) {
      print('❌ Connection failed: $e');
      if (EnvironmentConfig.enableDebugLogging) {
        print('Stack trace: $stackTrace');
      }
      throw Exception('Connection failed: $e');
    }
  }

  /// Disconnect from VPN and cleanup
  Future<void> disconnect() async {
    try {
      if (!_isConnected || _currentConfig == null || _connectedServer == null) {
        print('⚠️  Not connected');
        return;
      }

      print('🔌 Disconnecting from VPN...');

      // 1. STOP HTTP TUNNEL FIRST
      if (_httpTunnel != null) {
        print('🛑 Stopping HTTP tunnel...');
        await _httpTunnel!.stop();
        _httpTunnel!.printStatistics();
        _httpTunnel = null;
      }

      // 2. Stop WireGuard tunnel on phone
      final success = await WireGuardChannel.disconnect();

      if (!success) {
        print('⚠️  Failed to stop VPN tunnel');
      }

      // 3. Notify server to remove peer
      try {
        final endpoint = _connectedServer!.endpoint;

        await _dio.post(
          'https://$endpoint:8443/wireguard/disconnect',
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
            validateStatus: (status) => status == 200,
          ),
        );
        print('✅ Server notified of disconnection');
      } catch (e) {
        print('⚠️  Failed to notify server: $e');
      }

      _currentConfig = null;
      _isConnected = false;
      _connectedServer = null;

      print('╔════════════════════════════════════════╗');
      print('║   ✅ Disconnected Successfully         ║');
      print('╚════════════════════════════════════════╝');
    } catch (e) {
      print('❌ Error during disconnect: $e');
    }
  }

  /// Get tunnel statistics
  Map<String, int>? getTunnelStatistics() {
    return _httpTunnel?.getStatistics();
  }

  /// Get WireGuard statistics (for backward compatibility)
  Future<Map<String, int>> getStatistics() async {
    try {
      // Try to get statistics from WireGuard channel
      final stats = await WireGuardChannel.getStatistics();
      return stats;
    } catch (e) {
      return {
        'bytesSent': 0,
        'bytesReceived': 0,
      };
    }
  }
}
