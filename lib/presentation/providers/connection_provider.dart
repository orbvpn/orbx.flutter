import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../data/models/server.dart';
import '../../data/models/wireguard_config.dart';
import '../../data/repositories/server_repository.dart';
import '../../core/services/wireguard_service.dart';
import '../../core/platform/wireguard_channel.dart';
import '../../core/constants/mimicry_protocols.dart';
import '../../core/services/mimicry_manager.dart';

/// Connection states enum
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// Connection Provider - Manages VPN connection state
///
/// ✅ CRITICAL FIX: Now listens to EventChannel for ACTUAL state changes from Android
/// ✅ FIXED: Properly handles Map<Object?, Object?> from Android EventChannel
class ConnectionProvider with ChangeNotifier {
  final WireGuardService _wireguardService;
  final MimicryManager _mimicryManager;
  final ServerRepository _serverRepository;
  final Logger _logger = Logger();

  ConnectionState _state = ConnectionState.disconnected;
  OrbXServer? _currentServer;
  MimicryProtocol? _currentProtocol;
  WireGuardConfig? _config;
  String? _errorMessage;

  // Statistics
  DateTime? _connectionStartTime;
  Duration _connectionDuration = Duration.zero;
  int _bytesSent = 0;
  int _bytesReceived = 0;

  // ✅ NEW: Stream subscription for listening to native state changes
  StreamSubscription<dynamic>? _stateSubscription;
  Timer? _statsTimer;

  ConnectionProvider(
    this._wireguardService,
    this._mimicryManager,
    this._serverRepository,
  ) {
    // ✅ CRITICAL: Listen to native VPN state changes from Android
    _initializeStateListener();
  }

  // Getters
  ConnectionState get state => _state;
  OrbXServer? get currentServer => _currentServer;
  MimicryProtocol? get currentProtocol => _currentProtocol;
  String? get errorMessage => _errorMessage;
  DateTime? get connectionStartTime => _connectionStartTime;
  Duration get connectionDuration => _connectionDuration;
  int get bytesSent => _bytesSent;
  int get bytesReceived => _bytesReceived;

  bool get isConnected => _state == ConnectionState.connected;
  bool get isConnecting => _state == ConnectionState.connecting;
  bool get isDisconnecting => _state == ConnectionState.disconnecting;
  bool get isDisconnected => _state == ConnectionState.disconnected;

  /// ✅ NEW: Initialize EventChannel listener for native state changes
  void _initializeStateListener() {
    _logger.i('🎧 Initializing VPN state listener...');

    _stateSubscription = WireGuardChannel.connectionStateStream.listen(
      (event) {
        _logger.i('📡 Received state event from native: $event');
        _handleNativeStateChange(event);
      },
      onError: (error) {
        _logger.e('❌ State stream error: $error');
        // Don't set error state here - the stream error is usually a parsing issue
        // The actual VPN might still be working
      },
    );
  }

  /// ✅ FIXED: Handle state changes from native Android code
  /// Properly handles Map<Object?, Object?> type from Android
  void _handleNativeStateChange(dynamic event) {
    String state;

    // Handle both String and Map formats from Android
    if (event is String) {
      state = event;
    } else if (event is Map) {
      // ✅ FIXED: Android sends Map<Object?, Object?>, need to safely cast
      final stateValue = event['state'];
      if (stateValue == null) {
        _logger.w('⚠️  No state in event: $event');
        return;
      }
      state = stateValue.toString();
    } else {
      _logger.w('⚠️  Unknown event format: $event');
      return;
    }

    _logger.i('🔄 Processing state change: $state');

    switch (state.toLowerCase()) {
      case 'connecting':
        _state = ConnectionState.connecting;
        _errorMessage = null;
        break;

      case 'connected':
        _logger.i('✅ VPN CONNECTED!');
        _state = ConnectionState.connected;
        _connectionStartTime = DateTime.now();
        _errorMessage = null;
        // Start monitoring statistics
        _startMonitoring();
        break;

      case 'disconnecting':
        _state = ConnectionState.disconnecting;
        break;

      case 'disconnected':
        _logger.i('🔌 VPN DISCONNECTED');
        _state = ConnectionState.disconnected;
        _connectionStartTime = null;
        _connectionDuration = Duration.zero;
        _bytesSent = 0;
        _bytesReceived = 0;
        _errorMessage = null;
        // Stop monitoring
        _stopMonitoring();
        break;

      case 'error':
        _logger.e('❌ VPN ERROR');
        _state = ConnectionState.error;
        if (event is Map) {
          final errorValue = event['error'];
          if (errorValue != null) {
            _errorMessage = errorValue.toString();
          }
        }
        _stopMonitoring();
        break;

      default:
        _logger.w('⚠️  Unknown state: $state');
    }

    notifyListeners();
  }

  /// Connect to VPN server
  Future<void> connect({
    required OrbXServer server,
    MimicryProtocol? protocol,
    String? userCountryCode,
  }) async {
    try {
      _logger.i('🚀 Starting connection to ${server.name}...');

      // Update state immediately (will be overridden by native events)
      _state = ConnectionState.connecting;
      _currentServer = server;
      _currentProtocol = protocol;
      _errorMessage = null;
      notifyListeners();

      // Get WireGuard configuration from server
      _config = await _wireguardService.connect(server);

      _logger.i('✅ WireGuard config obtained, tunnel starting...');

      // Note: We don't set state to 'connected' here anymore!
      // We wait for the EventChannel to tell us when it's actually connected
    } catch (e) {
      _logger.e('❌ Connection error: $e');
      _state = ConnectionState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Disconnect from VPN
  Future<void> disconnect() async {
    try {
      _logger.i('🔌 Disconnecting from VPN...');

      _state = ConnectionState.disconnecting;
      notifyListeners();

      await _wireguardService.disconnect();

      // Note: State will be updated by EventChannel listener
      // when native code broadcasts the 'disconnected' state
    } catch (e) {
      _logger.e('❌ Disconnect error: $e');
      _state = ConnectionState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Switch to different protocol
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

  /// Start monitoring connection statistics
  void _startMonitoring() {
    _logger.i('📊 Starting statistics monitoring...');
    _stopMonitoring(); // Stop any existing timer

    // Update statistics every second
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_state != ConnectionState.connected) return;

      try {
        // Get statistics from WireGuard
        final stats = await _wireguardService.getStatistics();
        _bytesSent = stats['bytesSent'] ?? 0;
        _bytesReceived = stats['bytesReceived'] ?? 0;

        // Update connection duration
        if (_connectionStartTime != null) {
          _connectionDuration =
              DateTime.now().difference(_connectionStartTime!);
        }

        notifyListeners();
      } catch (e) {
        _logger.w('⚠️  Failed to get statistics: $e');
      }
    });
  }

  /// Stop monitoring statistics
  void _stopMonitoring() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _logger.i('📊 Statistics monitoring stopped');
  }

  /// Toggle connection (connect if disconnected, disconnect if connected)
  Future<void> toggleConnection({
    OrbXServer? server,
    MimicryProtocol? protocol,
    String? userCountryCode,
  }) async {
    if (isConnected || isConnecting) {
      await disconnect();
    } else if (isDisconnected) {
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

  @override
  void dispose() {
    _logger.i('🗑️  Disposing ConnectionProvider...');
    _stateSubscription?.cancel();
    _stopMonitoring();
    super.dispose();
  }
}
