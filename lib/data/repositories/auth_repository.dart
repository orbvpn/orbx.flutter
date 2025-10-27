// lib/data/repositories/auth_repository.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:logger/logger.dart';

import '../models/user.dart';
import '../models/auth_response.dart';
import '../api/graphql/client.dart';

class AuthRepository {
  final GraphQLService _graphQLService;
  final FlutterSecureStorage _secureStorage;
  final Logger _logger = Logger();

  // ✅ Cache access token only (backend doesn't return refresh token)
  String? _cachedAccessToken;

  AuthRepository({
    required GraphQLService graphQLService,
    required FlutterSecureStorage secureStorage,
  })  : _graphQLService = graphQLService,
        _secureStorage = secureStorage;

  /// Get cached access token synchronously
  String? getCachedToken() {
    return _cachedAccessToken;
  }

  /// Login user
  Future<AuthResponse> login(String email, String password) async {
    try {
      _logger.i('Attempting login for: $email');

      final result = await _graphQLService.client.mutate(
        MutationOptions(
          document: gql(r'''
            mutation Login($email: String!, $password: String!) {
              login(email: $email, password: $password) {
                accessToken
                user {
                  id
                  email
                  username
                  role
                  createdAt
                  profile {
                    firstName
                    lastName
                    phone
                    country
                  }
                }
              }
            }
          '''),
          variables: {'email': email, 'password': password},
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final data = result.data!['login'] as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String;
      final userData = data['user'] as Map<String, dynamic>;

      // ✅ Cache access token in memory
      _cachedAccessToken = accessToken;

      // Save token to secure storage
      await _secureStorage.write(key: 'auth_token', value: accessToken);

      // Save user data
      await _secureStorage.write(key: 'user_data', value: jsonEncode(userData));

      final user = User.fromJson(userData);
      _logger.i('Login successful: ${user.email}');

      return AuthResponse(accessToken: accessToken, user: user);
    } catch (e) {
      _logger.e('Login failed: $e');
      rethrow;
    }
  }

  /// Register new user
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? referralCode,
  }) async {
    try {
      _logger.i('Attempting registration for: $email');

      final result = await _graphQLService.client.mutate(
        MutationOptions(
          document: gql(r'''
            mutation Signup(
              $email: String!
              $password: String!
              $referral: String
            ) {
              signup(
                email: $email
                password: $password
                referral: $referral
              ) {
                success
                message
              }
            }
          '''),
          variables: {
            'email': email,
            'password': password,
            if (referralCode != null) 'referral': referralCode,
          },
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final data = result.data!['signup'] as Map<String, dynamic>;
      final success = data['success'] as bool;
      final message = data['message'] as String;

      if (!success) {
        throw Exception(message);
      }

      // After signup, need to login
      _logger.i('Signup successful, logging in...');
      return await login(email, password);
    } catch (e) {
      _logger.e('Registration failed: $e');
      rethrow;
    }
  }

  /// ✅ Refresh authentication token
  Future<bool> refreshToken() async {
    try {
      _logger.i('Attempting to refresh token');

      // Get current access token (backend uses it as refresh token)
      final currentToken =
          _cachedAccessToken ?? await _secureStorage.read(key: 'auth_token');

      if (currentToken == null || currentToken.isEmpty) {
        _logger.w('No token to refresh');
        return false;
      }

      // Call refresh token mutation
      final result = await _graphQLService.client.mutate(
        MutationOptions(
          document: gql(r'''
            mutation RefreshToken($refreshToken: String!) {
              refreshToken(refreshToken: $refreshToken) {
                accessToken
                user {
                  id
                  email
                  username
                  role
                  createdAt
                  profile {
                    firstName
                    lastName
                    phone
                    country
                  }
                }
              }
            }
          '''),
          variables: {'refreshToken': currentToken},
        ),
      );

      if (result.hasException) {
        _logger.e('Token refresh failed: ${result.exception}');
        return false;
      }

      final data = result.data!['refreshToken'] as Map<String, dynamic>;
      final newAccessToken = data['accessToken'] as String;
      final userData = data['user'] as Map<String, dynamic>;

      // ✅ Cache new token in memory
      _cachedAccessToken = newAccessToken;

      // Save new token to secure storage
      await _secureStorage.write(key: 'auth_token', value: newAccessToken);

      // Update user data
      await _secureStorage.write(key: 'user_data', value: jsonEncode(userData));

      _logger.i('✅ Token refreshed successfully');
      return true;
    } catch (e) {
      _logger.e('Token refresh error: $e');
      return false;
    }
  }

  /// Load user from storage
  Future<User?> loadUser() async {
    try {
      // ✅ Load and cache token
      _cachedAccessToken = await _secureStorage.read(key: 'auth_token');

      if (_cachedAccessToken == null) {
        return null;
      }

      final userDataJson = await _secureStorage.read(key: 'user_data');

      if (userDataJson == null) {
        return null;
      }

      final userData = jsonDecode(userDataJson) as Map<String, dynamic>;
      return User.fromJson(userData);
    } catch (e) {
      _logger.e('Failed to load user: $e');
      return null;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      // ✅ Clear cached token
      _cachedAccessToken = null;

      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'user_data');

      _logger.i('Logout successful');
    } catch (e) {
      _logger.e('Logout failed: $e');
      rethrow;
    }
  }

  /// Refresh user profile from backend
  Future<User> refreshUser() async {
    try {
      _logger.i('Refreshing user profile');

      final token =
          _cachedAccessToken ?? await _secureStorage.read(key: 'auth_token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final result = await _graphQLService.client.query(
        QueryOptions(
          document: gql(r'''
            query GetCurrentUser {
              me {
                id
                email
                username
                role
                createdAt
                profile {
                  firstName
                  lastName
                  phone
                  country
                }
              }
            }
          '''),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final userData = result.data!['me'] as Map<String, dynamic>;

      // Update stored user data
      await _secureStorage.write(key: 'user_data', value: jsonEncode(userData));

      final user = User.fromJson(userData);
      _logger.i('User profile refreshed');

      return user;
    } catch (e) {
      _logger.e('Failed to refresh user: $e');
      rethrow;
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      _logger.i('Attempting to change password');

      final result = await _graphQLService.client.mutate(
        MutationOptions(
          document: gql(r'''
            mutation ChangePassword($oldPassword: String!, $password: String!) {
              changePassword(oldPassword: $oldPassword, password: $password)
            }
          '''),
          variables: {'oldPassword': oldPassword, 'password': newPassword},
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final success = result.data!['changePassword'] as bool;

      _logger.i('Password change result: $success');
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

      final result = await _graphQLService.client.mutate(
        MutationOptions(
          document: gql(r'''
            mutation RequestPasswordReset($email: String!) {
              requestResetPassword(email: $email)
            }
          '''),
          variables: {'email': email},
        ),
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final success = result.data!['requestResetPassword'] as bool;

      _logger.i('Password reset request result: $success');
      return success;
    } catch (e) {
      _logger.e('Failed to request password reset: $e');
      rethrow;
    }
  }

  /// Get stored auth token (async)
  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: 'auth_token');
    } catch (e) {
      _logger.e('Failed to get token: $e');
      return null;
    }
  }
}
