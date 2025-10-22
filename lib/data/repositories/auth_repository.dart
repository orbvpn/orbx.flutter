import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/graphql/queries.dart';
import '../api/graphql/client.dart';
import '../models/user.dart';

class AuthRepository {
  final GraphQLService _graphql = GraphQLService.instance;
  final _storage = const FlutterSecureStorage();

  Future<AuthResponse> login(String email, String password) async {
    try {
      final result = await _graphql.mutate(
        GraphQLQueries.login,
        variables: {
          'email': email,
          'password': password,
        },
      );

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final data = result.data!['login'];

      // Store tokens
      await _storage.write(key: 'jwt_token', value: data['accessToken']);
      await _storage.write(key: 'refresh_token', value: data['refreshToken']);

      // Refresh GraphQL client with new token
      _graphql.refreshClient();

      return AuthResponse.fromJson(data);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    _graphql.refreshClient();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'jwt_token');
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
}
