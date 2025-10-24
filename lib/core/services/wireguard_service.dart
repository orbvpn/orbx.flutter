import 'package:dio/dio.dart';
import '../platform/wireguard_channel.dart';
import '../network/secure_http_client.dart';
import '../config/environment_config.dart';
import '../../data/models/wireguard_config.dart';
import '../../data/models/server.dart';
import '../../data/repositories/auth_repository.dart';

/// WireGuard VPN Service with automatic certificate management
class WireGuardService {
  final AuthRepository _authRepo;
  late final Dio _dio;

  WireGuardConfig? _currentConfig;
  bool _isConnected = false;
  OrbXServer? _connectedServer; // ✅ ADD THIS LINE

  bool get isConnected => _isConnected;
  WireGuardConfig? get currentConfig => _currentConfig;

  WireGuardService(this._authRepo) {
    _dio = SecureHttpClient.createOrbXClient(authRepository: _authRepo);
  }

  /// Connect to OrbX server with WireGuard
  Future<WireGuardConfig> connect(OrbXServer server) async {
    try {
      if (EnvironmentConfig.enableDebugLogging) {
        print('╔════════════════════════════════════════╗');
        print('║   Connecting to OrbX Server           ║');
        print('╠════════════════════════════════════════╣');
        print('║ Server: ${server.name.padRight(30)} ║');
        print('║ Location: ${server.location.padRight(28)} ║');
        print('║ IP: ${server.ipAddress.padRight(33)} ║');
        print('║ Port: ${server.port.toString().padRight(31)} ║');
        print('╚════════════════════════════════════════╝');
      }

      // 1. ALWAYS Generate NEW WireGuard keypair for each connection
      print('🔑 Generating NEW WireGuard keypair...');
      final keypair = await WireGuardChannel.generateKeypair();
      final privateKey = keypair['privateKey']!;
      final publicKey = keypair['publicKey']!;
      print('✅ New keypair generated');

      // 2. Get authentication token
      print('🎫 Retrieving authentication token...');
      final token = await _authRepo.getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated - please log in');
      }
      print('✅ Token retrieved');

      // 3. Register peer with server
      final endpoint = server.endpoint;
      final url = 'https://$endpoint:${server.port}/wireguard/connect';

      print('📞 Registering peer with server...');
      print('   URL: $url');

      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'publicKey': publicKey,
        },
      );

      print('📬 Server response: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception(
          'Server returned ${response.statusCode}: ${response.data}',
        );
      }

      final data = response.data as Map<String, dynamic>;
      print('✅ Peer registered successfully');

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
      _connectedServer = server; // ✅ ADD THIS LINE

      print('╔════════════════════════════════════════╗');
      print('║   ✅ Connection Established!           ║');
      print('╚════════════════════════════════════════╝');

      return config;
    } on DioException catch (e) {
      print('❌ Network error: ${e.message}');
      if (e.type == DioExceptionType.badCertificate) {
        print('   SSL certificate validation failed');
        print('   The server\'s certificate could not be verified');
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

  /// Disconnect from VPN and cleanup server-side peer
  Future<void> disconnect() async {
    try {
      if (!_isConnected || _currentConfig == null || _connectedServer == null) {
        print('⚠️  Not connected');
        return;
      }

      print('🔌 Disconnecting from VPN...');

      // 1. Stop WireGuard tunnel on phone
      final success = await WireGuardChannel.disconnect();

      if (!success) {
        print('⚠️  Failed to stop VPN tunnel');
      }

      // 2. Notify server to remove peer
      try {
        final token = await _authRepo.getAccessToken();
        if (token != null) {
          final endpoint = _connectedServer!.endpoint;
          await _dio.post(
            'https://$endpoint:${_connectedServer!.port}/wireguard/disconnect',
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
              },
              sendTimeout: Duration(seconds: 5),
              receiveTimeout: Duration(seconds: 5),
            ),
          );
          print('✅ Peer removed from server');
        }
      } catch (e) {
        print('⚠️  Failed to notify server: $e');
        // Don't throw - local disconnect already succeeded
      }

      _isConnected = false;
      _currentConfig = null;
      _connectedServer = null;

      print('✅ Disconnected successfully');
    } catch (e) {
      print('❌ Disconnect error: $e');
      rethrow;
    }
  }

  /// Get connection statistics
  Future<Map<String, int>> getStatistics() async {
    if (!_isConnected) {
      return {'bytesSent': 0, 'bytesReceived': 0};
    }

    try {
      return await WireGuardChannel.getStatistics();
    } catch (e) {
      print('⚠️  Failed to get statistics: $e');
      return {'bytesSent': 0, 'bytesReceived': 0};
    }
  }

  /// Check if VPN connection is active
  Future<bool> checkConnection() async {
    if (!_isConnected) {
      return false;
    }

    try {
      final status = await WireGuardChannel.getStatus();
      return status['connected'] == true;
    } catch (e) {
      print('⚠️  Failed to check connection: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}
