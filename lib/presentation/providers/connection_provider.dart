import 'package:flutter/foundation.dart';
import '../../data/models/server.dart';
import '../../data/models/wireguard_config.dart';
import '../../core/services/wireguard_service.dart';
import '../../core/services/mimicry_manager.dart';
import '../../core/constants/mimicry_protocols.dart';
import '../../data/repositories/server_repository.dart';

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

  // Connect to server
  Future<void> connect({
    required OrbXServer server,
    MimicryProtocol? protocol,
    String? userCountryCode,
  }) async {
    try {
      _state = ConnectionState.connecting;
      _errorMessage = null;
      notifyListeners();

      // 1. Establish WireGuard tunnel
      _config = await _wireguardService.connect(server);
      _currentServer = server;

      // 2. Determine best mimicry protocol
      if (protocol != null) {
        _currentProtocol = protocol;
      } else {
        _currentProtocol = await _mimicryManager.getBestProtocol(
          server,
          userCountryCode,
        );
      }

      // 3. Test protocol
      final protocolWorks = await _mimicryManager.testProtocol(
        server,
        _currentProtocol!,
      );

      if (protocolWorks != ProtocolStatus.working) {
        // Try to switch to working protocol
        final alternativeProtocol = await _mimicryManager.autoSwitchProtocol(
          server,
          userCountryCode,
        );

        if (alternativeProtocol != null) {
          _currentProtocol = alternativeProtocol;
        }
      }

      // 4. Mark as connected
      _state = ConnectionState.connected;
      _connectionStartTime = DateTime.now();

      // 5. Start monitoring connection
      _startMonitoring();

      notifyListeners();
    } catch (e) {
      _state = ConnectionState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

// Disconnect from VPN
  Future<void> disconnect() async {
    try {
      _state = ConnectionState.disconnecting;
      notifyListeners();

      await _wireguardService.disconnect();

      _state = ConnectionState.disconnected;
      _currentServer = null;
      _currentProtocol = null;
      _config = null;
      _connectionStartTime = null;
      _bytesSent = 0;
      _bytesReceived = 0;
      _connectionDuration = Duration.zero;

      notifyListeners();
    } catch (e) {
      _state = ConnectionState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Switch to different protocol
  Future<void> switchProtocol(MimicryProtocol newProtocol) async {
    if (_currentServer == null) return;

    try {
      final success = await _mimicryManager.switchProtocol(
        _currentServer!,
        newProtocol,
      );

      if (success) {
        _currentProtocol = newProtocol;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to switch protocol: $e';
      notifyListeners();
    }
  }

  // Monitor connection statistics
  void _startMonitoring() {
    // Update statistics every second
    Stream.periodic(const Duration(seconds: 1)).listen((_) async {
      if (_state != ConnectionState.connected) return;

      try {
        // Get statistics from WireGuard
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
      }
    });
  }

  // Toggle connection
  Future<void> toggleConnection({
    OrbXServer? server,
    MimicryProtocol? protocol,
    String? userCountryCode,
  }) async {
    if (isConnected) {
      await disconnect();
    } else {
      if (server != null) {
        await connect(
          server: server,
          protocol: protocol,
          userCountryCode: userCountryCode,
        );
      } else {
        // Auto-select best server
        final bestServer = await _serverRepository.getBestServer();
        if (bestServer != null) {
          await connect(
            server: bestServer,
            protocol: protocol,
            userCountryCode: userCountryCode,
          );
        } else {
          _errorMessage = 'No available servers';
          _state = ConnectionState.error;
          notifyListeners();
        }
      }
    }
  }
}
