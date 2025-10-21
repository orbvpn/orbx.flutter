import 'package:dio/dio.dart';
import '../constants/mimicry_protocols.dart';
import '../../data/models/server.dart';
import '../../data/repositories/auth_repository.dart';

enum ProtocolStatus { working, blocked, slow, unknown }

class MimicryManager {
  final AuthRepository _authRepo;
  final Dio _dio = Dio();

  MimicryManager(this._authRepo);

  MimicryProtocol _currentProtocol = MimicryProtocol.teams;
  Map<MimicryProtocol, ProtocolStatus> _protocolStatus = {};

  MimicryProtocol get currentProtocol => _currentProtocol;

  // Test if a protocol is working on a specific server
  Future<ProtocolStatus> testProtocol(
    OrbXServer server,
    MimicryProtocol protocol,
  ) async {
    try {
      final token = await _authRepo.getToken();
      if (token == null) {
        return ProtocolStatus.unknown;
      }

      final stopwatch = Stopwatch()..start();

      final response = await _dio.get(
        'https://${server.ipAddress}:${server.port}${protocol.endpoint}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      stopwatch.stop();

      if (response.statusCode == 200) {
        // Check latency
        if (stopwatch.elapsedMilliseconds > 3000) {
          return ProtocolStatus.slow;
        }
        return ProtocolStatus.working;
      } else {
        return ProtocolStatus.blocked;
      }
    } catch (e) {
      // Connection failed - likely blocked
      return ProtocolStatus.blocked;
    }
  }

  // Test all protocols on a server
  Future<Map<MimicryProtocol, ProtocolStatus>> testAllProtocols(
    OrbXServer server,
  ) async {
    final results = <MimicryProtocol, ProtocolStatus>{};

    for (final protocol in server.protocols) {
      results[protocol] = await testProtocol(server, protocol);
    }

    _protocolStatus = results;
    return results;
  }

  // Get best working protocol for current region
  Future<MimicryProtocol> getBestProtocol(
    OrbXServer server,
    String? userCountryCode,
  ) async {
    // 1. Test all protocols
    final statuses = await testAllProtocols(server);

    // 2. Filter working protocols
    final workingProtocols = statuses.entries
        .where((entry) => entry.value == ProtocolStatus.working)
        .map((entry) => entry.key)
        .toList();

    if (workingProtocols.isEmpty) {
      // Fallback to HTTPS
      return MimicryProtocol.https;
    }

    // 3. Prioritize region-specific protocols
    if (userCountryCode != null) {
      for (final protocol in workingProtocols) {
        final recommended = protocol.recommendedRegions;
        if (recommended.contains(userCountryCode) ||
            recommended.contains('*')) {
          return protocol;
        }
      }
    }

    // 4. Default to Teams (most universal)
    if (workingProtocols.contains(MimicryProtocol.teams)) {
      return MimicryProtocol.teams;
    }

    // 5. Return first working protocol
    return workingProtocols.first;
  }

  // Switch protocol (e.g., when current one gets blocked)
  Future<bool> switchProtocol(
    OrbXServer server,
    MimicryProtocol newProtocol,
  ) async {
    try {
      // Test if new protocol works
      final status = await testProtocol(server, newProtocol);

      if (status == ProtocolStatus.working) {
        _currentProtocol = newProtocol;
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Auto-switch to working protocol if current one fails
  Future<MimicryProtocol?> autoSwitchProtocol(
    OrbXServer server,
    String? userCountryCode,
  ) async {
    try {
      // Test current protocol
      final currentStatus = await testProtocol(server, _currentProtocol);

      if (currentStatus == ProtocolStatus.working) {
        return null; // Current protocol still works
      }

      // Find alternative
      final bestProtocol = await getBestProtocol(server, userCountryCode);

      if (bestProtocol != _currentProtocol) {
        _currentProtocol = bestProtocol;
        return bestProtocol;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Send data through mimicry protocol endpoint
  // This wraps the actual WireGuard traffic
  Future<void> sendThroughProtocol(
    OrbXServer server,
    MimicryProtocol protocol,
    List<int> data,
  ) async {
    final token = await _authRepo.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      await _dio.post(
        'https://${server.ipAddress}:${server.port}${protocol.endpoint}',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/octet-stream',
          },
          responseType: ResponseType.bytes,
        ),
      );
    } catch (e) {
      throw Exception('Failed to send data through protocol: $e');
    }
  }

  Map<MimicryProtocol, ProtocolStatus> get protocolStatuses => _protocolStatus;
}
