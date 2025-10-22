/// Authentication Repository
///
/// Handles all authentication-related business logic including:
/// - Login
/// - Registration
/// - Logout
/// - Token management
/// - User session management
library;

import 'package:logger/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';
import '../models/auth_response.dart';
import '../api/graphql/client.dart';
import '../api/graphql/queries.dart';
import '../../core/constants/api_constants.dart';

class AuthRepository {
  final GraphQLService _graphQLService;
  final FlutterSecureStorage _secureStorage;
  final Logger _logger = Logger();

  User? _currentUser;

  AuthRepository({
    GraphQLService? graphQLService,
    FlutterSecureStorage? secureStorage,
  })  : _graphQLService = graphQLService ?? GraphQLService.instance,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Get current authenticated user
  User? get currentUser => _currentUser;

  /// Check if user is currently authenticated
  Future<bool> isAuthenticated() async {
    return await _graphQLService.isAuthenticated();
  }

  /// Get the current access token
  ///
  /// Returns the JWT access token if available, null otherwise
  Future<String?> getAccessToken() async {
    return await _graphQLService.getAccessToken();
  }

  /// Login with email and password
  ///
  /// Returns [AuthResponse] containing tokens and user info
  /// Throws [Exception] on failure
  Future<AuthResponse> login(String email, String password) async {
    try {
      _logger.i('Attempting login for: $email');

      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }

      if (!_isValidEmail(email)) {
        throw Exception('Invalid email format');
      }

      // Execute login mutation
      final result = await _graphQLService.mutate(
        GraphQLQueries.login,
        variables: {
          'email': email,
          'password': password,
        },
        operationName: ApiConstants.loginOperation,
      );

      // Parse response
      final authResponse = AuthResponse.fromLoginJson(result);

      // Save tokens
      await _graphQLService.saveToken(
        authResponse.accessToken,
        authResponse.refreshToken,
      );

      // Save user data
      await _saveUserData(authResponse.user);

      // Set current user
      _currentUser = authResponse.user;

      _logger.i('Login successful for: ${authResponse.user.email}');
      return authResponse;
    } catch (e) {
      _logger.e('Login failed: $e');
      rethrow;
    }
  }

  /// Register new user account
  ///
  /// Returns [AuthResponse] containing tokens and user info
  /// Throws [Exception] on failure
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? referralCode,
  }) async {
    try {
      _logger.i('Attempting registration for: $email');

      // Validate inputs
      if (email.isEmpty ||
          password.isEmpty ||
          firstName.isEmpty ||
          lastName.isEmpty) {
        throw Exception('All fields are required');
      }

      if (!_isValidEmail(email)) {
        throw Exception('Invalid email format');
      }

      if (password.length < ApiConstants.minPasswordLength) {
        throw Exception(
          'Password must be at least ${ApiConstants.minPasswordLength} characters',
        );
      }

      if (password.length > ApiConstants.maxPasswordLength) {
        throw Exception(
          'Password must be less than ${ApiConstants.maxPasswordLength} characters',
        );
      }

      // Prepare input
      final input = {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        if (referralCode != null && referralCode.isNotEmpty)
          'referral': referralCode,
      };

      // Execute register mutation
      final result = await _graphQLService.mutate(
        GraphQLQueries.register,
        variables: {'input': input},
        operationName: ApiConstants.registerOperation,
      );

      // Parse response
      final authResponse = AuthResponse.fromRegisterJson(result);

      // Save tokens
      await _graphQLService.saveToken(
        authResponse.accessToken,
        authResponse.refreshToken,
      );

      // Save user data
      await _saveUserData(authResponse.user);

      // Set current user
      _currentUser = authResponse.user;

      _logger.i('Registration successful for: ${authResponse.user.email}');
      return authResponse;
    } catch (e) {
      _logger.e('Registration failed: $e');
      rethrow;
    }
  }

  /// Logout current user
  ///
  /// Clears all tokens and user data from storage
  Future<void> logout() async {
    try {
      _logger.i('Logging out user: ${_currentUser?.email}');

      // Clear tokens
      await _graphQLService.clearTokens();

      // Clear user data
      await _clearUserData();

      // Clear current user
      _currentUser = null;

      _logger.i('Logout successful');
    } catch (e) {
      _logger.e('Logout failed: $e');
      rethrow;
    }
  }

  /// Load user from secure storage
  ///
  /// Attempts to restore user session from stored data
  Future<User?> loadUser() async {
    try {
      _logger.i('Loading user from storage');

      // Check if authenticated
      final isAuth = await isAuthenticated();
      if (!isAuth) {
        _logger.w('No authentication token found');
        return null;
      }

      // Load user data from storage
      final userData = await _loadUserData();
      if (userData == null) {
        _logger.w('No user data found in storage');
        return null;
      }

      // Set current user
      _currentUser = userData;

      _logger.i('User loaded successfully: ${userData.email}');
      return userData;
    } catch (e) {
      _logger.e('Failed to load user: $e');
      return null;
    }
  }

  /// Refresh user profile from API
  ///
  /// Fetches latest user data from server
  Future<User> refreshUser() async {
    try {
      _logger.i('Refreshing user profile');

      // Execute query to get user profile
      final result = await _graphQLService.query(
        GraphQLQueries.getProfile,
        operationName: 'GetUserProfile',
      );

      // Parse user from response
      final userData = result['me'] as Map<String, dynamic>;
      final user = User.fromJson(userData);

      // Update stored user data
      await _saveUserData(user);

      // Update current user
      _currentUser = user;

      _logger.i('User profile refreshed successfully');
      return user;
    } catch (e) {
      _logger.e('Failed to refresh user: $e');
      rethrow;
    }
  }

  /// Refresh access token using refresh token
  ///
  /// Returns true if refresh was successful, false otherwise
  Future<bool> refreshToken() async {
    try {
      _logger.i('Attempting to refresh access token');

      // Get stored refresh token
      final refreshToken = await _secureStorage.read(key: 'refresh_token');

      if (refreshToken == null || refreshToken.isEmpty) {
        _logger.w('No refresh token available');
        return false;
      }

      // Call refresh token mutation
      final result = await _graphQLService.mutate(
        GraphQLQueries.refreshToken,
        variables: {'refreshToken': refreshToken},
        operationName: 'RefreshToken',
      );

      // Parse response
      final refreshData = result['refreshToken'] as Map<String, dynamic>;
      final newAccessToken = refreshData['accessToken'] as String;
      final newRefreshToken = refreshData['refreshToken'] as String?;

      // Save new tokens
      await _graphQLService.saveToken(newAccessToken, newRefreshToken);

      _logger.i('Token refreshed successfully');
      return true;
    } catch (e) {
      _logger.e('Token refresh failed: $e');
      return false;
    }
  }

  /// Change user password
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      _logger.i('Attempting to change password');

      if (newPassword.length < ApiConstants.minPasswordLength) {
        throw Exception(
          'Password must be at least ${ApiConstants.minPasswordLength} characters',
        );
      }

      // Execute change password mutation (you'll need to add this to queries.dart)
      final mutation = '''
        mutation ChangePassword(\$oldPassword: String!, \$password: String!) {
          changePassword(oldPassword: \$oldPassword, password: \$password)
        }
      ''';

      final result = await _graphQLService.mutate(
        mutation,
        variables: {
          'oldPassword': oldPassword,
          'password': newPassword,
        },
      );

      final success = result['changePassword'] as bool;

      if (success) {
        _logger.i('Password changed successfully');
      }

      return success;
    } catch (e) {
      _logger.e('Failed to change password: $e');
      rethrow;
    }
  }

  /// Request password reset
  Future<bool> requestPasswordReset(String email) async {
    try {
      _logger.i('Requesting password reset for: $email');

      if (!_isValidEmail(email)) {
        throw Exception('Invalid email format');
      }

      // Execute reset password mutation
      final mutation = '''
        mutation RequestResetPassword(\$email: String!) {
          requestResetPassword(email: \$email)
        }
      ''';

      final result = await _graphQLService.mutate(
        mutation,
        variables: {'email': email},
      );

      final success = result['requestResetPassword'] as bool;

      if (success) {
        _logger.i('Password reset email sent to: $email');
      }

      return success;
    } catch (e) {
      _logger.e('Failed to request password reset: $e');
      rethrow;
    }
  }

  // ==========================================
  // Private Helper Methods
  // ==========================================

  /// Validate email format
  bool _isValidEmail(String email) {
    final regex = RegExp(ApiConstants.emailPattern);
    return regex.hasMatch(email);
  }

  /// Save user data to secure storage
  Future<void> _saveUserData(User user) async {
    try {
      final userJson = user.toJson();
      await _secureStorage.write(
        key: 'user_data',
        value: userJson.toString(),
      );
      await _secureStorage.write(
        key: ApiConstants.userIdKey,
        value: user.id,
      );
      await _secureStorage.write(
        key: ApiConstants.userEmailKey,
        value: user.email,
      );
    } catch (e) {
      _logger.e('Error saving user data: $e');
      rethrow;
    }
  }

  /// Load user data from secure storage
  Future<User?> _loadUserData() async {
    try {
      final userDataString = await _secureStorage.read(key: 'user_data');
      if (userDataString == null) return null;

      // For simplicity, we'll use stored email and id to reconstruct basic user
      // In production, you might want to fetch from API or use better serialization
      final userId = await _secureStorage.read(key: ApiConstants.userIdKey);
      final userEmail =
          await _secureStorage.read(key: ApiConstants.userEmailKey);

      if (userId == null || userEmail == null) return null;

      // Fetch full user profile from API
      return await refreshUser();
    } catch (e) {
      _logger.e('Error loading user data: $e');
      return null;
    }
  }

  /// Clear user data from secure storage
  Future<void> _clearUserData() async {
    try {
      await _secureStorage.delete(key: 'user_data');
      await _secureStorage.delete(key: ApiConstants.userIdKey);
      await _secureStorage.delete(key: ApiConstants.userEmailKey);
    } catch (e) {
      _logger.e('Error clearing user data: $e');
      rethrow;
    }
  }
}
