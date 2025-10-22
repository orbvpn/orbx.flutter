/// Application-wide Constants
///
/// Contains app metadata, feature flags, and general configuration
/// that doesn't fit into specific categories.
library;

class AppConstants {
  AppConstants._(); // Private constructor

  // ==========================================
  // App Metadata
  // ==========================================

  static const String appName = 'OrbVPN';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // ==========================================
  // Feature Flags
  // ==========================================

  /// Enable quantum-safe encryption
  static const bool quantumSafeEnabled = true;

  /// Enable protocol mimicry (all 10 protocols)
  static const bool protocolMimicryEnabled = true;

  /// Enable auto-reconnect on connection drop
  static const bool autoReconnectEnabled = true;

  /// Enable kill switch (block traffic if VPN drops)
  static const bool killSwitchEnabled = true;

  /// Enable split tunneling
  static const bool splitTunnelingEnabled = true;

  // ==========================================
  // Connection Defaults
  // ==========================================

  /// Default connection timeout in seconds
  static const int defaultConnectionTimeoutSeconds = 30;

  /// Maximum reconnection attempts
  static const int maxReconnectionAttempts = 3;

  /// Delay between reconnection attempts (seconds)
  static const int reconnectionDelaySeconds = 5;

  /// Connection health check interval (seconds)
  static const int healthCheckIntervalSeconds = 60;

  // ==========================================
  // Data Usage & Statistics
  // ==========================================

  /// Update statistics interval (seconds)
  static const int statsUpdateIntervalSeconds = 5;

  /// Maximum stored session history
  static const int maxSessionHistory = 100;

  /// Data units
  static const int bytesPerKB = 1024;
  static const int bytesPerMB = 1024 * 1024;
  static const int bytesPerGB = 1024 * 1024 * 1024;

  // ==========================================
  // UI Constants
  // ==========================================

  /// Default animation duration
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  /// Splash screen minimum duration
  static const Duration splashScreenDuration = Duration(seconds: 2);

  /// Toast/Snackbar duration
  static const Duration snackbarDuration = Duration(seconds: 3);

  /// Debounce duration for search/filter
  static const Duration debounceDuration = Duration(milliseconds: 500);

  // ==========================================
  // Pagination & Lists
  // ==========================================

  /// Default page size for paginated lists
  static const int defaultPageSize = 20;

  /// Maximum items to load at once
  static const int maxItemsPerLoad = 50;

  // ==========================================
  // Cache & Storage
  // ==========================================

  /// Cache expiration duration (hours)
  static const Duration cacheExpirationDuration = Duration(hours: 24);

  /// Maximum cache size (MB)
  static const int maxCacheSizeMB = 100;

  /// Hive box names
  static const String serverCacheBox = 'server_cache';
  static const String usageCacheBox = 'usage_cache';
  static const String settingsBox = 'settings';

  // ==========================================
  // Notifications
  // ==========================================

  /// FCM notification channel ID
  static const String fcmChannelId = 'orbvpn_notifications';

  /// FCM notification channel name
  static const String fcmChannelName = 'OrbVPN Notifications';

  /// FCM notification channel description
  static const String fcmChannelDescription =
      'Notifications for connection status, usage alerts, and important updates';

  // ==========================================
  // URLs & Links
  // ==========================================

  static const String privacyPolicyUrl = 'https://orbvpn.com/privacy';
  static const String termsOfServiceUrl = 'https://orbvpn.com/terms';
  static const String supportUrl = 'https://orbvpn.com/support';
  static const String websiteUrl = 'https://orbvpn.com';

  // ==========================================
  // Contact & Support
  // ==========================================

  static const String supportEmail = 'support@orbvpn.com';
  static const String feedbackEmail = 'feedback@orbvpn.com';

  // ==========================================
  // Device Limits
  // ==========================================

  /// Default maximum devices per account
  static const int defaultMaxDevices = 5;

  /// Maximum devices per account (hard limit)
  static const int absoluteMaxDevices = 10;

  // ==========================================
  // Protocol Mimicry Types
  // ==========================================

  /// All supported protocol mimicry types
  static const List<String> supportedProtocols = [
    'Teams', // Microsoft Teams traffic
    'Google Drive', // Google Drive uploads/downloads
    'Google Meet', // Google Meet video calls
    'Zoom', // Zoom meetings
    'Shaparak', // Iranian banking protocol
    'DNS over HTTPS', // DoH queries
    'Fragmented HTTPS', // Packet fragmentation
    'TLS 1.3', // Standard TLS
    'HTTP/2', // HTTP/2 protocol
    'WebSocket', // WebSocket connections
  ];

  // ==========================================
  // Error Messages
  // ==========================================

  static const String genericErrorMessage =
      'Something went wrong. Please try again.';
  static const String networkErrorMessage =
      'Network error. Please check your internet connection.';
  static const String serverErrorMessage =
      'Server error. Please try again later.';
  static const String authenticationErrorMessage =
      'Authentication failed. Please log in again.';

  // ==========================================
  // Success Messages
  // ==========================================

  static const String loginSuccessMessage = 'Successfully logged in!';
  static const String registerSuccessMessage = 'Account created successfully!';
  static const String connectionSuccessMessage = 'Connected to VPN!';
  static const String disconnectionSuccessMessage = 'Disconnected from VPN!';
}
