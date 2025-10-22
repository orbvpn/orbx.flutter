/// Authentication Provider
///
/// Manages authentication state and provides authentication methods to the UI.
/// Uses Provider pattern for state management.

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';

/// Authentication states
enum AuthStatus {
  initial, // App just started
  authenticated, // User is logged in
  unauthenticated, // User is not logged in
  loading, // Processing authentication
}

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;
  final Logger _logger = Logger();

  AuthStatus _status = AuthStatus.initial;
  User? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  AuthProvider(this._authRepository);

  // ==========================================
  // Getters
  // ==========================================

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get hasError => _errorMessage != null;

  // ==========================================
  // Authentication Methods
  // ==========================================

  /// Initialize authentication
  ///
  /// Attempts to load user from storage on app start
  Future<void> initialize() async {
    try {
      _logger.i('Initializing authentication');
      _setLoading(true);

      final user = await _authRepository.loadUser();

      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
        _logger.i('User loaded from storage: ${user.email}');
      } else {
        _status = AuthStatus.unauthenticated;
        _logger.i('No stored user found');
      }
    } catch (e) {
      _logger.e('Initialization error: $e');
      _status = AuthStatus.unauthenticated;
      _setError('Failed to initialize authentication');
    } finally {
      _setLoading(false);
    }
  }

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Login attempt for: $email');
      _clearError();
      _setLoading(true);

      final authResponse = await _authRepository.login(email, password);

      _currentUser = authResponse.user;
      _status = AuthStatus.authenticated;

      _logger.i('Login successful: ${authResponse.user.email}');
      _setLoading(false);

      return true;
    } catch (e) {
      _logger.e('Login failed: $e');
      _setError(_extractErrorMessage(e));
      _status = AuthStatus.unauthenticated;
      _setLoading(false);

      return false;
    }
  }

  /// Register new user
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? referralCode,
  }) async {
    try {
      _logger.i('Registration attempt for: $email');
      _clearError();
      _setLoading(true);

      final authResponse = await _authRepository.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        referralCode: referralCode,
      );

      _currentUser = authResponse.user;
      _status = AuthStatus.authenticated;

      _logger.i('Registration successful: ${authResponse.user.email}');
      _setLoading(false);

      return true;
    } catch (e) {
      _logger.e('Registration failed: $e');
      _setError(_extractErrorMessage(e));
      _status = AuthStatus.unauthenticated;
      _setLoading(false);

      return false;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      _logger.i('Logout attempt');
      _setLoading(true);

      await _authRepository.logout();

      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _clearError();

      _logger.i('Logout successful');
    } catch (e) {
      _logger.e('Logout failed: $e');
      _setError(_extractErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh user profile
  Future<void> refreshUser() async {
    try {
      _logger.i('Refreshing user profile');
      _clearError();

      final user = await _authRepository.refreshUser();

      _currentUser = user;
      _status = AuthStatus.authenticated;

      notifyListeners();
      _logger.i('User profile refreshed');
    } catch (e) {
      _logger.e('Failed to refresh user: $e');
      _setError(_extractErrorMessage(e));

      // If refresh fails due to auth error, logout
      if (e.toString().toLowerCase().contains('authentication') ||
          e.toString().toLowerCase().contains('unauthorized')) {
        await logout();
      }
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      _logger.i('Attempting to change password');
      _clearError();
      _setLoading(true);

      final success = await _authRepository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (success) {
        _logger.i('Password changed successfully');
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _logger.e('Failed to change password: $e');
      _setError(_extractErrorMessage(e));
      _setLoading(false);

      return false;
    }
  }

  /// Request password reset
  Future<bool> requestPasswordReset(String email) async {
    try {
      _logger.i('Requesting password reset for: $email');
      _clearError();
      _setLoading(true);

      final success = await _authRepository.requestPasswordReset(email);

      if (success) {
        _logger.i('Password reset email sent');
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _logger.e('Failed to request password reset: $e');
      _setError(_extractErrorMessage(e));
      _setLoading(false);

      return false;
    }
  }

  // ==========================================
  // Helper Methods
  // ==========================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Extract user-friendly error message from exception
  String _extractErrorMessage(Object error) {
    final errorString = error.toString();

    // Remove "Exception: " prefix if present
    if (errorString.startsWith('Exception: ')) {
      return errorString.substring(11);
    }

    // Check for common error patterns and provide friendly messages
    if (errorString.toLowerCase().contains('network')) {
      return 'Network error. Please check your internet connection.';
    }

    if (errorString.toLowerCase().contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorString.toLowerCase().contains('invalid credentials') ||
        errorString.toLowerCase().contains('authentication failed')) {
      return 'Invalid email or password.';
    }

    if (errorString.toLowerCase().contains('user already exists') ||
        errorString.toLowerCase().contains('email already registered')) {
      return 'An account with this email already exists.';
    }

    if (errorString.toLowerCase().contains('validation')) {
      return 'Please check your input and try again.';
    }

    // Return original message if no pattern matches
    return errorString;
  }

  /// Clear all state (useful for testing)
  void clear() {
    _status = AuthStatus.initial;
    _currentUser = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
