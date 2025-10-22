import 'package:flutter/foundation.dart';
import '../../data/repositories/server_repository.dart';
import '../../data/models/server.dart';

class ServerProvider extends ChangeNotifier {
  final ServerRepository _serverRepository;

  ServerProvider(this._serverRepository);

  List<OrbXServer> _servers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<OrbXServer> get servers => _servers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load all available servers
  Future<void> loadServers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _servers = await _serverRepository.getAvailableServers();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh server list
  Future<void> refreshServers() async {
    await loadServers();
  }

  /// Get best server based on load and latency
  Future<OrbXServer?> getBestServer() async {
    try {
      return await _serverRepository.getBestServer();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Get server by ID
  Future<OrbXServer?> getServerById(String id) async {
    try {
      return await _serverRepository.getServerById(id);
    } catch (e) {
      return null;
    }
  }

  /// Filter servers by region
  List<OrbXServer> filterByRegion(String region) {
    return _serverRepository.filterByRegion(region);
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
