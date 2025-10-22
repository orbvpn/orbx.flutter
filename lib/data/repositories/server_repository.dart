import '../api/graphql/queries.dart';
import '../api/graphql/client.dart';
import '../models/server.dart';
import '../../core/services/network_analyzer.dart';
import '../../core/constants/mimicry_protocols.dart';

class ServerRepository {
  final GraphQLService _graphql = GraphQLService.instance;
  final NetworkAnalyzer _networkAnalyzer;

  List<OrbXServer> _cachedServers = [];

  ServerRepository(this._networkAnalyzer);

// Fetch all available servers from OrbNet API
  Future<List<OrbXServer>> getAvailableServers() async {
    try {
      final data = await _graphql.query(GraphQLQueries.getServers);

      print('🔍 DEBUG: Query response data: $data'); // ✅ Add this

      final serversJson = data['orbxServers'] as List<dynamic>;

      print('🔍 DEBUG: Server count: ${serversJson.length}'); // ✅ Add this
      print(
          '🔍 DEBUG: First server (if any): ${serversJson.isNotEmpty ? serversJson.first : "EMPTY"}'); // ✅ Add this

      _cachedServers = serversJson
          .map((json) => OrbXServer.fromJson(json as Map<String, dynamic>))
          .toList();

      print('🔍 DEBUG: Parsed ${_cachedServers.length} servers'); // ✅ Add this

      return _cachedServers;
    } catch (e) {
      print('❌ DEBUG: Error fetching servers: $e'); // ✅ Add this
      throw Exception('Failed to fetch servers: $e');
    }
  }

  // Get best server automatically
  Future<OrbXServer?> getBestServer() async {
    try {
      // Try GraphQL API first (it has server-side logic)
      final data = await _graphql.query(GraphQLQueries.getBestServer);

      final serverJson = data['bestOrbXServer'];
      if (serverJson != null) {
        return OrbXServer.fromJson(serverJson as Map<String, dynamic>);
      }

      // Fallback: client-side selection
      if (_cachedServers.isEmpty) {
        await getAvailableServers();
      }

      return await _networkAnalyzer.findBestServer(_cachedServers);
    } catch (e) {
      // If API call fails, fallback to client-side selection
      if (_cachedServers.isEmpty) {
        await getAvailableServers();
      }
      return await _networkAnalyzer.findBestServer(_cachedServers);
    }
  }

  // Get server by ID
  Future<OrbXServer?> getServerById(String id) async {
    try {
      final data = await _graphql.query(
        GraphQLQueries.getServerById,
        variables: {'id': id},
      );

      final serverJson = data['orbxServer'];
      if (serverJson == null) return null;

      return OrbXServer.fromJson(serverJson as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // Refresh server list with latency measurements
  Future<List<OrbXServer>> refreshServersWithLatency() async {
    final servers = await getAvailableServers();

    // Measure latency for each
    final latencies = await _networkAnalyzer.measureBatchLatency(servers);

    // Update servers with measured latency
    _cachedServers = servers.map((server) {
      final latency = latencies[server];
      return server.copyWith(latencyMs: latency);
    }).toList();

    return _cachedServers;
  }

  // Filter servers by region
  List<OrbXServer> filterByRegion(String region) {
    return _cachedServers
        .where((s) => s.country.toLowerCase().contains(region.toLowerCase()))
        .toList();
  }

  // Filter servers by protocol support
  List<OrbXServer> filterByProtocol(MimicryProtocol protocol) {
    return _cachedServers.where((s) => s.protocols.contains(protocol)).toList();
  }

  // Get cached servers
  List<OrbXServer> getCachedServers() => _cachedServers;
}
