import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  // Monitor connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream {
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

      // Reverse geocode using OpenStreetMap Nominatim
      final countryCode = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      return countryCode;
    } catch (e) {
      return null;
    }
  }

  // Reverse geocode coordinates to country code
  Future<String?> _reverseGeocode(double latitude, double longitude) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$latitude'
        '&lon=$longitude'
        '&format=json'
        '&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'OrbVPN/1.0.0', // Required by Nominatim
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract country code from address
        final countryCode = data['address']?['country_code'] as String?;

        if (countryCode != null) {
          return countryCode
              .toUpperCase(); // Return as uppercase (e.g., "US", "IR")
        }
      }

      return null;
    } catch (e) {
      // Fallback: Try to get country from IP geolocation
      return await _getCountryFromIP();
    }
  }

  // Fallback: Get country from IP address (more reliable, doesn't need location permission)
  Future<String?> _getCountryFromIP() async {
    try {
      // Using ip-api.com (free, no API key needed, 45 requests/minute)
      final url = Uri.parse('http://ip-api.com/json/?fields=countryCode');

      final response = await http.get(url).timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['countryCode'] as String?;
      }

      return null;
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
