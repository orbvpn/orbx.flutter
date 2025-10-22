import 'package:dio/dio.dart';
import '../platform/wireguard_channel.dart';
import '../../data/models/wireguard_config.dart';
import '../../data/models/server.dart';
import '../../data/repositories/auth_repository.dart';

class WireGuardService {
  final AuthRepository _authRepo;
  final Dio _dio = Dio();

  WireGuardService(this._authRepo);

  WireGuardConfig? _currentConfig;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  WireGuardConfig? get currentConfig => _currentConfig;

  // Connect to OrbX server
  Future<WireGuardConfig> connect(OrbXServer server) async {
    try {
      // 1. Generate WireGuard keypair locally
      final keypair = await WireGuardChannel.generateKeypair();
      final privateKey = keypair['privateKey']!;
      final publicKey = keypair['publicKey']!;

      // 2. Get JWT token
      final token = await _authRepo.getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // 3. Call OrbX server to register peer
      final response = await _dio.post(
        'https://${server.ipAddress}:${server.port}/wireguard/connect',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
        data: {'publicKey': publicKey},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to connect to server');
      }

      final data = response.data;

      // 4. Build WireGuard configuration
      final config = WireGuardConfig(
        privateKey: privateKey,
        publicKey: publicKey,
        serverPublicKey: data['serverPublicKey'] as String? ?? '',
        allocatedIp: data['ip'] as String,
        gateway: data['gateway'] as String,
        dns: List<String>.from(data['dns'] as List),
        mtu: data['mtu'] as int,
        serverEndpoint: '${server.ipAddress}:51820', // WireGuard UDP port
      );

      // 5. Establish WireGuard tunnel
      final success = await WireGuardChannel.connect(config);

      if (!success) {
        throw Exception('Failed to establish tunnel');
      }

      _currentConfig = config;
      _isConnected = true;

      return config;
    } catch (e) {
      throw Exception('Connection failed: $e');
    }
  }

  // Disconnect from VPN
  Future<void> disconnect(OrbXServer server) async {
    try {
      // 1. Disconnect WireGuard tunnel
      await WireGuardChannel.disconnect();

      // 2. Notify server
      final token = await _authRepo.getAccessToken();
      if (token != null) {
        await _dio.post(
          'https://${server.ipAddress}:${server.port}/wireguard/disconnect',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }

      _currentConfig = null;
      _isConnected = false;
    } catch (e) {
      throw Exception('Disconnect failed: $e');
    }
  }

  // Get current statistics
  Future<Map<String, int>> getStatistics() async {
    return await WireGuardChannel.getStatistics();
  }

  // Get connection status
  Future<Map<String, dynamic>> getStatus() async {
    return await WireGuardChannel.getStatus();
  }

  // Stream of connection state changes
  Stream<String> get connectionStateStream {
    return WireGuardChannel.connectionStateStream;
  }
}
