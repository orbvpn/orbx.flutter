class ApiConstants {
  // OrbNet GraphQL API
  static const String orbnetEndpoint = 'https://orbnet.xyz/graphql';

  // OrbX servers use HTTPS on port 8443
  static const int orbxPort = 8443;

  // WireGuard uses UDP on port 51820
  static const int wireguardPort = 51820;

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Retry policy
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Latency test timeout
  static const Duration latencyTimeout = Duration(seconds: 5);
}
