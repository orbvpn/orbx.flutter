import 'package:flutter/foundation.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthProvider(this._authRepository);

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  // Login
  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _authRepository.login(email, password);
      _currentUser = response.user;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    await _authRepository.logout();
    _currentUser = null;
    notifyListeners();
  }

  // Check if user is logged in
  Future<bool> checkAuth() async {
    try {
      return await _authRepository.isLoggedIn();
    } catch (e) {
      return false;
    }
  }
}
