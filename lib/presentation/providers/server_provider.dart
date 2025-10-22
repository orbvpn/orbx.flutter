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

  Future<void> refreshServers() async {
    await loadServers();
  }
}
