import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GraphQLService {
  static GraphQLService? _instance;
  static GraphQLService get instance => _instance ??= GraphQLService._();

  GraphQLService._();

  final _storage = const FlutterSecureStorage();
  GraphQLClient? _client;

  Future<GraphQLClient> getClient() async {
    if (_client != null) return _client!;

    final token = await _storage.read(key: 'jwt_token');

    final httpLink = HttpLink('https://api.orbvpn.com/graphql');

    final authLink = AuthLink(
      getToken: () async => token != null ? 'Bearer $token' : null,
    );

    final link = authLink.concat(httpLink);

    _client = GraphQLClient(
      cache: GraphQLCache(store: InMemoryStore()),
      link: link,
    );

    return _client!;
  }

  // Refresh client when token changes
  void refreshClient() {
    _client = null;
  }

  Future<QueryResult> query(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final client = await getClient();
    return await client.query(
      QueryOptions(document: gql(query), variables: variables ?? {}),
    );
  }

  Future<QueryResult> mutate(
    String mutation, {
    Map<String, dynamic>? variables,
  }) async {
    final client = await getClient();
    return await client.mutate(
      MutationOptions(document: gql(mutation), variables: variables ?? {}),
    );
  }
}
