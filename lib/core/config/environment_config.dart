/// Environment configuration for OrbX application
///
/// Manages different configurations for development, staging, and production.
library;

enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  /// Current environment
  static Environment current = Environment.development;

  static bool get isDevelopment => current == Environment.development;
  static bool get isStaging => current == Environment.staging;
  static bool get isProduction => current == Environment.production;

  // ==========================================
  // API Configuration
  // ==========================================

  /// OrbNet GraphQL API endpoint (dynamically configured)
  static String orbnetApiUrl = 'https://orbnet.xyz/graphql';

  /// Update OrbNet API URL (can be changed at runtime)
  static void setOrbNetApiUrl(String url) {
    orbnetApiUrl = url;
    if (enableDebugLogging) {
      print('🔧 OrbNet API URL updated: $url');
    }
  }

  // ==========================================
  // SSL/TLS Configuration
  // ==========================================

  /// Trust-On-First-Use (TOFU) certificate validation
  ///
  /// Development: Automatically trust new certificates
  /// Staging: Automatically trust new certificates with warnings
  /// Production: Require server-provided certificate fingerprints
  static bool get useTrustOnFirstUse {
    switch (current) {
      case Environment.development:
        return true; // Auto-trust in dev
      case Environment.staging:
        return true; // Auto-trust in staging
      case Environment.production:
        return false; // Require explicit validation in prod
    }
  }

  /// Allow automatic certificate updates when cert changes
  ///
  /// Development: Yes (servers often renew certs)
  /// Staging: Yes (with security warning)
  /// Production: No (require manual approval)
  static bool get allowAutomaticCertificateUpdates {
    switch (current) {
      case Environment.development:
        return true;
      case Environment.staging:
        return true;
      case Environment.production:
        return false; // Require user confirmation
    }
  }

  /// Whether to enable debug logging
  static bool get enableDebugLogging => !isProduction;

  /// Whether to show verbose network logs
  static bool get showNetworkLogs => isDevelopment;

  // ==========================================
  // Timeout Configuration
  // ==========================================

  static Duration get connectionTimeout {
    switch (current) {
      case Environment.development:
        return const Duration(seconds: 60);
      case Environment.staging:
      case Environment.production:
        return const Duration(seconds: 30);
    }
  }

  static Duration get receiveTimeout {
    switch (current) {
      case Environment.development:
        return const Duration(seconds: 60);
      case Environment.staging:
      case Environment.production:
        return const Duration(seconds: 30);
    }
  }

  // ==========================================
  // Feature Flags
  // ==========================================

  static bool get enableCrashReporting => isProduction || isStaging;
  static bool get enableAnalytics => isProduction || isStaging;
  static bool get enablePerformanceMonitoring => isProduction || isStaging;
  static bool get showDebugInfo => isDevelopment;

  // ==========================================
  // App Configuration
  // ==========================================

  static String get appName {
    switch (current) {
      case Environment.development:
        return 'OrbVPN [DEV]';
      case Environment.staging:
        return 'OrbVPN [STAGING]';
      case Environment.production:
        return 'OrbVPN';
    }
  }

  static String get appSuffix {
    switch (current) {
      case Environment.development:
        return '.dev';
      case Environment.staging:
        return '.staging';
      case Environment.production:
        return '';
    }
  }

  // ==========================================
  // Utility Methods
  // ==========================================

  static void setEnvironment(String env) {
    switch (env.toLowerCase()) {
      case 'dev':
      case 'development':
        current = Environment.development;
        break;
      case 'staging':
      case 'stage':
        current = Environment.staging;
        break;
      case 'prod':
      case 'production':
        current = Environment.production;
        break;
      default:
        throw ArgumentError('Unknown environment: $env');
    }
  }

  static String get environmentName {
    switch (current) {
      case Environment.development:
        return 'development';
      case Environment.staging:
        return 'staging';
      case Environment.production:
        return 'production';
    }
  }

  static void printConfig() {
    print('╔════════════════════════════════════════╗');
    print('║    OrbVPN Environment Configuration    ║');
    print('╠════════════════════════════════════════╣');
    print('║ Environment: ${environmentName.padRight(25)} ║');
    print('║ OrbNet API: ${orbnetApiUrl.substring(0, 26).padRight(26)} ║');
    print(
        '║ Trust-On-First-Use: ${useTrustOnFirstUse.toString().padRight(17)} ║');
    print(
        '║ Auto-Update Certs: ${allowAutomaticCertificateUpdates.toString().padRight(18)} ║');
    print('║ Debug Logging: ${enableDebugLogging.toString().padRight(21)} ║');
    print('║ Network Logs: ${showNetworkLogs.toString().padRight(22)} ║');
    print('╚════════════════════════════════════════╝');
  }
}
