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
    (dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
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

      // ✅ NEW FLOW: Skip REST endpoint, go straight to native tunnel
      // The Android/iOS native code will:
      // 1. Establish HTTP tunnel to /vpn/tunnel
      // 2. Server will register the peer via that endpoint
      // 3. WireGuard packets flow through the HTTP tunnel

      print('🎭 Initiating HTTP tunnel connection with $protocol mimicry...');
      print('   Endpoint: $endpoint:8443 (via /vpn/tunnel)');

      // 3. Build WireGuard configuration for native layer
      // Note: We don't know the allocated IP yet - the server will assign it via tunnel
      print('⚙️  Building WireGuard configuration...');

      // TEMPORARY: Use placeholder IP until tunnel establishes
      // The native layer will update this after tunnel handshake
      final config = WireGuardConfig(
        privateKey: privateKey,
        publicKey: publicKey,
        serverPublicKey:
            'oMqzsUVApNEplc4CipCZG5DkN334SlcFUQhbMm1qkE8=', // Your server's public key
        allocatedIp: '10.8.0.2', // Placeholder - will be assigned by server
        gateway: '10.8.0.1',
        dns: ['1.1.1.1', '1.0.0.1'],
        mtu: 1420,
        serverEndpoint: '$endpoint:51820',
        protocol: protocol,
        authToken: authToken,
      );

      if (EnvironmentConfig.enableDebugLogging) {
        print('   Allocated IP: ${config.allocatedIp} (placeholder)');
        print('   Gateway: ${config.gateway}');
        print('   DNS: ${config.dns.join(", ")}');
        print('   MTU: ${config.mtu}');
        print('   Endpoint: ${config.serverEndpoint}');
        print('   Protocol: $protocol');
      }

      // 4. Establish WireGuard tunnel with HTTP mimicry
      // This will trigger the Android native code to:
      // - Start HTTP tunnel to /vpn/tunnel
      // - Establish WireGuard connection through the tunnel
      print('🔌 Establishing WireGuard tunnel with HTTP mimicry...');
      final success = await WireGuardChannel.connect(config);

      if (!success) {
        throw Exception('Failed to establish WireGuard tunnel');
      }

      _currentConfig = config;
      _isConnected = true;
      _connectedServer = server;

      // 5. Initialize HTTP tunnel service for statistics tracking
      print('📊 Initializing tunnel statistics tracking...');
      _httpTunnel = HttpTunnelService(
        serverAddress: endpoint,
        authToken: authToken,
        protocol: protocol,
      );

      // Note: We don't call start() here because the native layer already started it
      // This is just for tracking statistics in Flutter layer
      print('✅ HTTP tunnel active');

      print('╔════════════════════════════════════════╗');
      print('║   ✅ Connection Established!           ║');
      print('║   🎭 Traffic disguised as $protocol    ║');
      print('║   🔒 Packets flowing through tunnel    ║');
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
