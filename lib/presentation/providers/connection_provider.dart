import 'package:flutter/foundation.dart';
import '../../data/models/server.dart';
import '../../data/models/wireguard_config.dart';
import '../../core/services/wireguard_service.dart';
import '../../core/services/mimicry_manager.dart';
import '../../core/constants/mimicry_protocols.dart';
import '../../data/repositories/server_repository.dart';
import '../../core/platform/wireguard_channel.dart';

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class ConnectionProvider extends ChangeNotifier {
  final WireGuardService _wireguardService;
  final MimicryManager _mimicryManager;
  final ServerRepository _serverRepository;

  ConnectionProvider(
    this._wireguardService,
    this._mimicryManager,
    this._serverRepository,
  );

  ConnectionState _state = ConnectionState.disconnected;
  OrbXServer? _currentServer;
  MimicryProtocol? _currentProtocol;
  WireGuardConfig? _config;
  String? _errorMessage;

  int _bytesSent = 0;
  int _bytesReceived = 0;
  Duration _connectionDuration = Duration.zero;
  DateTime? _connectionStartTime;

  // Getters
  ConnectionState get state => _state;
  OrbXServer? get currentServer => _currentServer;
  MimicryProtocol? get currentProtocol => _currentProtocol;
  WireGuardConfig? get config => _config;
  String? get errorMessage => _errorMessage;
  int get bytesSent => _bytesSent;
  int get bytesReceived => _bytesReceived;
  Duration get connectionDuration => _connectionDuration;

  bool get isConnected => _state == ConnectionState.connected;
  bool get isConnecting => _state == ConnectionState.connecting;
  bool get isDisconnecting => _state == ConnectionState.disconnecting;

  /// Connect to VPN server
  Future<void> connect({
    required OrbXServer server,
    required String authToken,
    MimicryProtocol? protocol,
    String? userCountryCode,
  }) async {
    try {
      _state = ConnectionState.connecting;
      _errorMessage = null;
      notifyListeners();

      print('🔄 Starting connection process...');

      // 1. Determine best protocol
      if (protocol != null) {
        _currentProtocol = protocol;
      } else {
        _currentProtocol = await _mimicryManager.getBestProtocol(
          server,
          userCountryCode,
        );
      }

      print('🎭 Selected protocol: ${_currentProtocol?.name ?? "teams"}');

      // 2. Generate WireGuard keypair
      print('🔑 Generating WireGuard keypair...');
      final keypair = await WireGuardChannel.generateKeypair();
      final publicKey = keypair['publicKey']!;
      final privateKey = keypair['privateKey']!;

      // 3. Connect to server with all required parameters
      _config = await _wireguardService.connect(
        server: server,
        authToken: authToken,
        publicKey: publicKey,
        privateKey: privateKey,
        protocol: _currentProtocol?.name.toLowerCase() ?? 'teams',
      );

      _currentServer = server;

      // 4. Mark as connected
      _state = ConnectionState.connected;
      _connectionStartTime = DateTime.now();

      print('✅ Connection established successfully');

      // 5. Start monitoring connection
      _startMonitoring();

      notifyListeners();
    } catch (e) {
      print('❌ Connection failed: $e');
      _state = ConnectionState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Disconnect from VPN
  Future<void> disconnect() async {
    try {
      _state = ConnectionState.disconnecting;
      notifyListeners();

      print('🔌 Disconnecting from VPN...');

      // Disconnect WireGuard (handles HTTP tunnel cleanup internally)
      await _wireguardService.disconnect();

      _state = ConnectionState.disconnected;
      _currentServer = null;
      _currentProtocol = null;
      _config = null;
      _connectionStartTime = null;
      _bytesSent = 0;
      _bytesReceived = 0;
      _connectionDuration = Duration.zero;

      print('✅ Disconnected successfully');

      notifyListeners();
    } catch (e) {
      print('❌ Disconnect failed: $e');
      _state = ConnectionState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Switch to different protocol (re-establishes connection)
  Future<void> switchProtocol(
    MimicryProtocol newProtocol,
    String authToken,
  ) async {
    if (_currentServer == null) {
      print('⚠️  Cannot switch protocol: no active server');
      return;
    }

    try {
      print('🔄 Switching to ${newProtocol.name} protocol...');

      // Re-establish connection with new protocol
      await disconnect();
      await connect(
        server: _currentServer!,
        authToken: authToken,
        protocol: newProtocol,
      );

      print('✅ Switched to ${newProtocol.name} protocol');
    } catch (e) {
      print('❌ Protocol switch failed: $e');
      _errorMessage = 'Failed to switch protocol: $e';
      notifyListeners();
    }
  }

  /// Get HTTP tunnel statistics
  Map<String, int>? getHttpTunnelStats() {
    return _wireguardService.getTunnelStatistics();
  }

  /// Monitor connection statistics
  void _startMonitoring() {
    // Update statistics every second
    Stream.periodic(const Duration(seconds: 1)).listen((_) async {
      if (_state != ConnectionState.connected) return;

      try {
        // Get statistics from WireGuard service
        final stats = await _wireguardService.getStatistics();
        _bytesSent = stats['bytesSent'] ?? 0;
        _bytesReceived = stats['bytesReceived'] ?? 0;

        // Update connection duration
        if (_connectionStartTime != null) {
          _connectionDuration = DateTime.now().difference(
            _connectionStartTime!,
          );
        }

        notifyListeners();
      } catch (e) {
        // Ignore errors during monitoring
        if (kDebugMode) {
          print('⚠️  Monitoring error: $e');
        }
      }
    });
  }

  /// Toggle connection (smart connect/disconnect)
  Future<void> toggleConnection({
    OrbXServer? server,
    String? authToken,
    MimicryProtocol? protocol,
    String? userCountryCode,
  }) async {
    if (isConnected) {
      await disconnect();
    } else {
      // Validate auth token
      if (authToken == null || authToken.isEmpty) {
        _errorMessage = 'Authentication required';
        _state = ConnectionState.error;
        notifyListeners();
        return;
      }

      if (server != null) {
        // Connect to specified server
        await connect(
          server: server,
          authToken: authToken,
          protocol: protocol,
          userCountryCode: userCountryCode,
        );
      } else {
        // Auto-select best server
        print('🔍 Auto-selecting best server...');
        final bestServer = await _serverRepository.getBestServer();

        if (bestServer != null) {
          await connect(
            server: bestServer,
            authToken: authToken,
            protocol: protocol,
            userCountryCode: userCountryCode,
          );
        } else {
          print('❌ No available servers found');
          _errorMessage = 'No available servers';
          _state = ConnectionState.error;
          notifyListeners();
        }
      }
    }
  }
}
