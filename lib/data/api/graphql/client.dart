// lib/data/api/graphql/client.dart

import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

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
      'https://orbnet.xyz/graphql',
    );

    // ✅ Auth link to add Bearer token to requests
    final authLink = AuthLink(
      getToken: () async {
        try {
          // ✅ Read token from the SAME key that AuthRepository writes to
          final token = await _storage.read(key: 'auth_token');

          if (token != null && token.isNotEmpty) {
            _logger.d('✅ Adding auth token to request');
            return 'Bearer $token';
          }

          _logger.w('⚠️  No auth token available');
          return null;
        } catch (e) {
          _logger.e('❌ Error getting token: $e');
          return null;
        }
      },
    );

    // ✅ Error link for handling errors
    final errorLink = ErrorLink(
      onException: (request, forward, exception) {
        _logger.e('⛔ GraphQL Exception: ${exception.toString()}');
        return forward(request);
      },
      onGraphQLError: (request, forward, response) {
        _logger.e('⛔ GraphQL Error: ${response.errors}');
        return forward(request);
      },
    );

    // ✅ Combine links in correct order: error -> auth -> http
    final link = Link.from([errorLink, authLink, httpLink]);

    _client = GraphQLClient(
      cache: GraphQLCache(store: InMemoryStore()),
      link: link,
      defaultPolicies: DefaultPolicies(
        watchQuery: Policies(fetch: FetchPolicy.networkOnly),
        query: Policies(fetch: FetchPolicy.networkOnly),
        mutate: Policies(fetch: FetchPolicy.networkOnly),
      ),
    );

    _logger.i('✅ GraphQL client initialized successfully');
  }

  /// Get the GraphQL client instance
  GraphQLClient get client {
    if (_client == null) {
      throw Exception(
        'GraphQL client not initialized. Call initialize() first.',
      );
    }
    return _client!;
  }

  /// Perform a GraphQL query
  Future<Map<String, dynamic>> query(
    String query, {
    Map<String, dynamic>? variables,
    String? operationName,
  }) async {
    try {
      _logger.d('🐛 Executing query: $operationName');
      _logger.d('🐛 Variables: $variables');

      final options = QueryOptions(
        document: gql(query),
        variables: variables ?? {},
        fetchPolicy: FetchPolicy.networkOnly,
      );

      final result = await client.query(options);

      if (result.hasException) {
        _logger.e('⛔ Query exception: ${result.exception}');
        throw _handleGraphQLException(result.exception!);
      }

      if (result.data == null) {
        _logger.e('⛔ Query returned null data');
        throw Exception('No data returned from query');
      }

      _logger.i('✅ Query successful: $operationName');
      return result.data!;
    } catch (e) {
      _logger.e('⛔ Query error: $e');
      rethrow;
    }
  }

  /// Perform a GraphQL mutation
  Future<Map<String, dynamic>> mutate(
    String mutation, {
    Map<String, dynamic>? variables,
    String? operationName,
  }) async {
    try {
      _logger.d('🐛 Executing mutation: $operationName');
      _logger.d('🐛 Variables: $variables');

      final options = MutationOptions(
        document: gql(mutation),
        variables: variables ?? {},
        fetchPolicy: FetchPolicy.networkOnly,
      );

      final result = await client.mutate(options);

      if (result.hasException) {
        _logger.e('⛔ Mutation exception: ${result.exception}');
        throw _handleGraphQLException(result.exception!);
      }

      if (result.data == null) {
        _logger.e('⛔ Mutation returned null data');
        throw Exception('No data returned from mutation');
      }

      _logger.i('✅ Mutation successful: $operationName');
      return result.data!;
    } catch (e) {
      _logger.e('⛔ Mutation error: $e');
      rethrow;
    }
  }

  /// Handle GraphQL exceptions
  Exception _handleGraphQLException(OperationException exception) {
    // Check for authentication errors
    if (exception.graphqlErrors.isNotEmpty) {
      for (final error in exception.graphqlErrors) {
        if (error.extensions != null) {
          final classification = error.extensions?['classification'];

          if (classification == 'UNAUTHENTICATED') {
            return Exception('Authentication failed: Please log in again');
          }

          if (classification == 'UNAUTHORIZED') {
            return Exception('Access denied: Insufficient permissions');
          }
        }
      }

      // Return first error message
      return Exception(exception.graphqlErrors.first.message);
    }

    // Check for network errors
    if (exception.linkException != null) {
      return Exception('Network error: Please check your connection');
    }

    return Exception('Request failed: Unknown error');
  }
}
