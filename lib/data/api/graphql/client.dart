/// GraphQL Service
///
/// Handles all GraphQL communication with the OrbNet API.
/// Singleton pattern for consistent client instance.

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '/../core/constants/api_constants.dart';

class GraphQLService {
  static final GraphQLService _instance = GraphQLService._internal();
  static GraphQLService get instance => _instance;

  GraphQLClient? _client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Logger _logger = Logger();

  GraphQLService._internal();

  /// Initialize the GraphQL client
  Future<void> initialize() async {
    final httpLink = HttpLink(
      ApiConstants.orbnetEndpoint,
    );

    // Auth link to add Bearer token to requests
    final authLink = AuthLink(
      getToken: () async {
        final token = await _storage.read(key: ApiConstants.accessTokenKey);
        return token != null ? '${ApiConstants.bearerPrefix} $token' : null;
      },
    );

    // Error link for handling errors
    final errorLink = ErrorLink(
      onException: (request, forward, exception) {
        _logger.e('GraphQL Exception: ${exception.toString()}');
        return forward(request);
      },
      onGraphQLError: (request, forward, response) {
        _logger.e('GraphQL Error: ${response.errors}');
        return forward(request);
      },
      onNetworkError: (request, forward, exception) {
        _logger.e('Network Error: ${exception.toString()}');
        return forward(request);
      },
    );

    final link = Link.from([
      errorLink,
      authLink,
      httpLink,
    ]);

    _client = GraphQLClient(
      cache: GraphQLCache(store: InMemoryStore()),
      link: link,
      defaultPolicies: DefaultPolicies(
        watchQuery: Policies(
          fetch: FetchPolicy.networkOnly,
        ),
        query: Policies(
          fetch: FetchPolicy.networkOnly,
        ),
        mutate: Policies(
          fetch: FetchPolicy.networkOnly,
        ),
      ),
    );

    _logger.i('GraphQL client initialized successfully');
  }

  /// Get the GraphQL client instance
  GraphQLClient get client {
    if (_client == null) {
      throw Exception(
          'GraphQL client not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Perform a GraphQL query
  ///
  /// Returns the data if successful, throws exception otherwise
  Future<Map<String, dynamic>> query(
    String query, {
    Map<String, dynamic>? variables,
    String? operationName,
  }) async {
    try {
      _logger.d('Executing query: $operationName');
      _logger.d('Variables: $variables');

      final options = QueryOptions(
        document: gql(query),
        variables: variables ?? {},
        fetchPolicy: FetchPolicy.networkOnly,
      );

      final result = await client.query(options);

      if (result.hasException) {
        _logger.e('Query exception: ${result.exception}');
        throw _handleGraphQLException(result.exception!);
      }

      if (result.data == null) {
        _logger.e('Query returned null data');
        throw Exception('No data returned from query');
      }

      _logger.i('Query successful: $operationName');
      return result.data!;
    } catch (e) {
      _logger.e('Query error: $e');
      rethrow;
    }
  }

  /// Perform a GraphQL mutation
  ///
  /// Returns the data if successful, throws exception otherwise
  Future<Map<String, dynamic>> mutate(
    String mutation, {
    Map<String, dynamic>? variables,
    String? operationName,
  }) async {
    try {
      _logger.d('Executing mutation: $operationName');
      _logger.d('Variables: $variables');

      final options = MutationOptions(
        document: gql(mutation),
        variables: variables ?? {},
        fetchPolicy: FetchPolicy.networkOnly,
      );

      final result = await client.mutate(options);

      if (result.hasException) {
        _logger.e('Mutation exception: ${result.exception}');
        throw _handleGraphQLException(result.exception!);
      }

      if (result.data == null) {
        _logger.e('Mutation returned null data');
        throw Exception('No data returned from mutation');
      }

      _logger.i('Mutation successful: $operationName');
      return result.data!;
    } catch (e) {
      _logger.e('Mutation error: $e');
      rethrow;
    }
  }

  /// Save authentication token to secure storage
  Future<void> saveToken(String accessToken, String refreshToken) async {
    try {
      await _storage.write(
        key: ApiConstants.accessTokenKey,
        value: accessToken,
      );
      await _storage.write(
        key: ApiConstants.refreshTokenKey,
        value: refreshToken,
      );
      _logger.i('Tokens saved to secure storage');
    } catch (e) {
      _logger.e('Error saving tokens: $e');
      rethrow;
    }
  }

  /// Get access token from secure storage
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: ApiConstants.accessTokenKey);
    } catch (e) {
      _logger.e('Error reading access token: $e');
      return null;
    }
  }

  /// Get refresh token from secure storage
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: ApiConstants.refreshTokenKey);
    } catch (e) {
      _logger.e('Error reading refresh token: $e');
      return null;
    }
  }

  /// Clear all stored tokens
  Future<void> clearTokens() async {
    try {
      await _storage.delete(key: ApiConstants.accessTokenKey);
      await _storage.delete(key: ApiConstants.refreshTokenKey);
      _logger.i('Tokens cleared from secure storage');
    } catch (e) {
      _logger.e('Error clearing tokens: $e');
      rethrow;
    }
  }

  /// Check if user is authenticated (has valid token)
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Handle GraphQL exceptions and convert to meaningful errors
  Exception _handleGraphQLException(OperationException exception) {
    // Check for network errors
    if (exception.linkException != null) {
      final linkException = exception.linkException!;
      if (linkException is NetworkException) {
        return Exception(
            'Network error: Please check your internet connection');
      }
      if (linkException is ServerException) {
        return Exception(
            'Server error: ${linkException.parsedResponse?.errors?.first.message ?? "Unknown error"}');
      }
      return Exception('Connection error: ${linkException.toString()}');
    }

    // Check for GraphQL errors
    if (exception.graphqlErrors.isNotEmpty) {
      final error = exception.graphqlErrors.first;
      final message = error.message;

      // Handle specific error types
      if (message.toLowerCase().contains('unauthorized') ||
          message.toLowerCase().contains('authentication')) {
        return Exception('Authentication failed: Please log in again');
      }

      if (message.toLowerCase().contains('not found')) {
        return Exception('Resource not found: $message');
      }

      if (message.toLowerCase().contains('validation')) {
        return Exception('Validation error: $message');
      }

      return Exception('API error: $message');
    }

    return Exception('Unknown error occurred');
  }

  /// Dispose resources
  void dispose() {
    _client = null;
    _logger.i('GraphQL client disposed');
  }
}
