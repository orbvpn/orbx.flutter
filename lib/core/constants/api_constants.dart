/// API Configuration Constants for OrbVPN
///
/// This file contains all API endpoints, configurations, and network settings
/// used throughout the application.
library;

class ApiConstants {
  ApiConstants._(); // Private constructor to prevent instantiation

  // ==========================================
  // OrbNet API (Central Management - GraphQL)
  // ==========================================

  /// Production OrbNet GraphQL endpoint
  static const String orbnetGraphQLEndpoint = 'https://orbnet.xyz/graphql';

  /// Development/Testing OrbNet endpoint (if needed)
  static const String orbnetGraphQLEndpointDev =
      'http://localhost:8080/graphql';

  /// Use production by default
  static const String orbnetEndpoint = orbnetGraphQLEndpoint;

  // ==========================================
  // OrbX Protocol Servers (HTTP/HTTPS)
  // ==========================================

  /// OrbX servers are fetched dynamically from OrbNet API
  /// Base ports for different protocols
  static const int orbxHttpPort = 8443;
  static const int orbxHttpsPort = 443;

  // ==========================================
  // Timeouts & Retry Configuration
  // ==========================================

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Maximum retry attempts for failed requests
  static const int maxRetries = 3;

  /// Delay between retry attempts
  static const Duration retryDelay = Duration(seconds: 2);

  // ==========================================
  // Headers
  // ==========================================

  static const String contentTypeJson = 'application/json';
  static const String authorizationHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer';

  // ==========================================
  // GraphQL Operation Names
  // ==========================================

  static const String loginOperation = 'Login';
  static const String registerOperation = 'Register';
  static const String getServersOperation = 'GetOrbXServers';
  static const String getBestServerOperation = 'GetBestOrbXServer';
  static const String recordUsageOperation = 'RecordOrbXUsage';
  static const String loginDeviceOperation = 'LoginDevice';
  static const String logoutDeviceOperation = 'LogoutDevice';

  // ==========================================
  // Storage Keys (for tokens, user data)
  // ==========================================

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userEmailKey = 'user_email';
  static const String deviceIdKey = 'device_id';

  // ==========================================
  // API Response Status
  // ==========================================

  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusServerError = 500;

  // ==========================================
  // Validation
  // ==========================================

  /// Email validation pattern
  static const String emailPattern =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  /// Minimum password length
  static const int minPasswordLength = 8;

  /// Maximum password length
  static const int maxPasswordLength = 128;

  // ==========================================
  // Environment Configuration
  // ==========================================

  /// Set to false in production!
  static const bool isDevelopment = true; // TODO: Use build flavors

  /// Accept self-signed certificates (DEVELOPMENT ONLY)
  static const bool acceptSelfSignedCertificates = isDevelopment;
}
