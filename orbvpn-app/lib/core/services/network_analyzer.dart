import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/server.dart';

class NetworkAnalyzer {
  final Connectivity _connectivity = Connectivity();

  // Test latency to a server
  Future<int> measureLatency(String host, int port) async {
    final stopwatch = Stopwatch()..start();

    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return 9999; // Unreachable
    }
  }

  // Batch test latency for multiple servers
  Future<Map<OrbXServer, int>> measureBatchLatency(
    List<OrbXServer> servers,
  ) async {
    final results = <OrbXServer, int>{};

    // Test in parallel
    final futures = servers.map((server) async {
      final latency = await measureLatency(server.ipAddress, server.port);
      results[server] = latency;
    });

    await Future.wait(futures);

    return results;
  }

  // Find best server based on latency and load
  Future<OrbXServer?> findBestServer(List<OrbXServer> servers) async {
    if (servers.isEmpty) return null;

    // Measure latency for all servers
    final latencies = await measureBatchLatency(servers);

    // Filter servers with acceptable latency (<500ms)
    final goodServers =
        latencies.entries.where((entry) => entry.value < 500).toList()
          ..sort((a, b) {
            // Sort by: 1) latency, 2) load percentage
            final latencyDiff = a.value.compareTo(b.value);
            if (latencyDiff != 0) return latencyDiff;

            final loadA = a.key.loadPercentage;
            final loadB = b.key.loadPercentage;
            return loadA.compareTo(loadB);
          });

    if (goodServers.isEmpty) {
      // No server with good latency, return least loaded
      return servers.reduce(
        (a, b) => a.loadPercentage < b.loadPercentage ? a : b,
      );
    }

    return goodServers.first.key;
  }

  // Check internet connectivity
  Future<bool> hasInternetConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // Monitor connectivity changes
  Stream<ConnectivityResult> get connectivityStream {
    return _connectivity.onConnectivityChanged;
  }

  // Get user's approximate location (for server selection)
  Future<String?> getUserCountryCode() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return null;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // Note: You'll need a reverse geocoding service to convert
      // coordinates to country code. For now, return null.
      // In production, use: https://nominatim.openstreetmap.org/reverse

      return null; // TODO: Implement reverse geocoding
    } catch (e) {
      return null;
    }
  }

  // Test if a specific port is reachable
  Future<bool> isPortOpen(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if WireGuard UDP port is accessible
  Future<bool> isWireGuardAccessible(String host) async {
    // UDP connectivity test is tricky on mobile
    // We'll use TCP health check as proxy
    return await isPortOpen(host, 8443);
  }
}
