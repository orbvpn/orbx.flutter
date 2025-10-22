import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment_config.dart';

/// Automatic Certificate Manager with Trust-On-First-Use (TOFU)
///
/// This manager automatically learns and trusts certificates from servers,
/// storing them securely for future validation. No manual intervention needed!
///
/// Features:
/// - Automatic certificate learning on first connection
/// - Persistent storage of trusted certificates
/// - Certificate change detection (possible MITM attack)
/// - Optional validation against server-provided fingerprints
/// - Works with any hostname dynamically
class CertificateManager {
  static const String _storageKey = 'trusted_certificates_v1';
  static SharedPreferences? _prefs;

  /// Cache of trusted certificates: hostname -> fingerprint
  static Map<String, String> _trustedCertificates = {};

  /// Whether to enable debug logging
  static bool debugLogging = true;

  /// Initialize the certificate manager
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadTrustedCertificates();

    if (debugLogging) {
      print('🔐 Certificate Manager initialized');
      print('   Trusted certificates: ${_trustedCertificates.length}');
      print('   Environment: ${EnvironmentConfig.environmentName}');
    }
  }

  /// Load trusted certificates from storage
  static Future<void> _loadTrustedCertificates() async {
    try {
      final stored = _prefs?.getString(_storageKey);
      if (stored != null) {
        final Map<String, dynamic> data = json.decode(stored);
        _trustedCertificates = data.map(
          (key, value) => MapEntry(key, value.toString()),
        );

        if (debugLogging) {
          print(
              '📋 Loaded ${_trustedCertificates.length} trusted certificates from storage');
        }
      }
    } catch (e) {
      print('⚠️  Failed to load trusted certificates: $e');
      _trustedCertificates = {};
    }
  }

  /// Save trusted certificates to storage
  static Future<void> _saveTrustedCertificates() async {
    try {
      final encoded = json.encode(_trustedCertificates);
      await _prefs?.setString(_storageKey, encoded);

      if (debugLogging) {
        print(
            '💾 Saved ${_trustedCertificates.length} trusted certificates to storage');
      }
    } catch (e) {
      print('⚠️  Failed to save trusted certificates: $e');
    }
  }

  /// Get SHA-256 fingerprint of a certificate
  static String getCertificateFingerprint(X509Certificate cert) {
    return sha256
        .convert(cert.der)
        .toString()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-F0-9]'), '');
  }

  /// Validate certificate with Trust-On-First-Use (TOFU) approach
  ///
  /// Returns true if:
  /// 1. Certificate matches previously trusted fingerprint for this host
  /// 2. First time seeing this host (auto-trust and store)
  /// 3. Development mode with self-signed certs enabled
  static bool validateCertificate(
    X509Certificate cert,
    String host,
    int port, {
    String? expectedFingerprint,
  }) {
    // Check if certificate is expired
    if (_isCertificateExpired(cert)) {
      print('❌ Certificate expired for $host:$port');
      return false;
    }

    // Get certificate fingerprint
    final fingerprint = getCertificateFingerprint(cert);

    if (debugLogging) {
      print('🔐 Certificate validation for $host:$port');
      print('   Subject: ${cert.subject}');
      print('   Issuer: ${cert.issuer}');
      print('   Fingerprint: ${fingerprint.substring(0, 32)}...');
      print('   Valid from: ${cert.startValidity}');
      print('   Valid to: ${cert.endValidity}');
    }

    // If server provided expected fingerprint, validate against it
    if (expectedFingerprint != null) {
      final normalizedExpected = expectedFingerprint
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-F0-9]'), '');

      if (fingerprint == normalizedExpected) {
        // Trust and store this certificate
        _trustCertificate(host, fingerprint);
        print('✅ Certificate matches server-provided fingerprint');
        return true;
      } else {
        print('❌ Certificate does NOT match server-provided fingerprint');
        print('   Expected: ${normalizedExpected.substring(0, 32)}...');
        print('   Got: ${fingerprint.substring(0, 32)}...');
        return false;
      }
    }

    // Check if we've seen this host before
    final trustedFingerprint = _trustedCertificates[host];

    if (trustedFingerprint == null) {
      // First time seeing this host - TOFU (Trust On First Use)
      if (EnvironmentConfig.isDevelopment || EnvironmentConfig.isStaging) {
        print('🆕 First connection to $host - trusting certificate (TOFU)');
        print('   Fingerprint: $fingerprint');
        _trustCertificate(host, fingerprint);
        return true;
      } else if (EnvironmentConfig.isProduction) {
        // In production, require explicit trust or server-provided fingerprint
        print('❌ Unknown certificate in production mode');
        print('   Host: $host');
        print('   Fingerprint: $fingerprint');
        print('   Production requires server-provided certificate validation');
        return false;
      }

      // Should never reach here, but return false as fallback
      return false;
    }

    // We've seen this host before - validate fingerprint matches
    if (fingerprint == trustedFingerprint) {
      if (debugLogging) {
        print('✅ Certificate matches trusted fingerprint for $host');
      }
      return true;
    }

    // Certificate changed! Possible MITM attack
    // At this point, trustedFingerprint is guaranteed non-null
    print('⚠️  🚨 SECURITY ALERT: Certificate changed for $host');
    print('   Expected: ${trustedFingerprint.substring(0, 32)}...');
    print('   Got: ${fingerprint.substring(0, 32)}...');
    print('   This could indicate:');
    print('   - Server certificate was renewed (normal)');
    print('   - Man-in-the-middle attack (security risk!)');

    // In development, allow certificate updates
    if (EnvironmentConfig.isDevelopment) {
      print('   Development mode: Updating trusted certificate');
      _trustCertificate(host, fingerprint);
      return true;
    }

    // In production, reject changed certificates
    print('   Production mode: REJECTING changed certificate');
    return false;
  }

  /// Trust a certificate for a host and persist to storage
  static void _trustCertificate(String host, String fingerprint) {
    _trustedCertificates[host] = fingerprint;
    _saveTrustedCertificates();
  }

  /// Manually trust a certificate (for certificate updates in production)
  static Future<void> trustCertificate(String host, String fingerprint) async {
    print('🔐 Manually trusting certificate for $host');
    _trustCertificate(host, fingerprint);
  }

  /// Remove trusted certificate for a host
  static Future<void> removeTrustedCertificate(String host) async {
    _trustedCertificates.remove(host);
    await _saveTrustedCertificates();
    print('🗑️  Removed trusted certificate for $host');
  }

  /// Clear all trusted certificates
  static Future<void> clearAllTrustedCertificates() async {
    _trustedCertificates.clear();
    await _saveTrustedCertificates();
    print('🗑️  Cleared all trusted certificates');
  }

  /// Get all trusted certificates (for debugging/UI)
  static Map<String, String> getAllTrustedCertificates() {
    return Map.unmodifiable(_trustedCertificates);
  }

  /// Check if certificate is expired
  static bool _isCertificateExpired(X509Certificate cert) {
    final now = DateTime.now();
    final isExpired =
        now.isAfter(cert.endValidity) || now.isBefore(cert.startValidity);

    if (isExpired && debugLogging) {
      print('⚠️  Certificate is expired or not yet valid');
      print('   Valid from: ${cert.startValidity}');
      print('   Valid to: ${cert.endValidity}');
      print('   Current time: $now');
    }

    return isExpired;
  }

  /// Export trusted certificates (for backup/sync)
  static String exportTrustedCertificates() {
    return json.encode(_trustedCertificates);
  }

  /// Import trusted certificates (from backup/sync)
  static Future<void> importTrustedCertificates(String exported) async {
    try {
      final Map<String, dynamic> data = json.decode(exported);
      _trustedCertificates = data.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      await _saveTrustedCertificates();
      print('✅ Imported ${_trustedCertificates.length} trusted certificates');
    } catch (e) {
      print('❌ Failed to import certificates: $e');
      throw Exception('Invalid certificate data');
    }
  }

  /// Get certificate info for display in UI
  static Map<String, dynamic>? getCertificateInfo(String host) {
    final fingerprint = _trustedCertificates[host];
    if (fingerprint == null) return null;

    return {
      'host': host,
      'fingerprint': fingerprint,
      'fingerprintShort': '${fingerprint.substring(0, 16)}...',
    };
  }

  /// Check if host is trusted
  static bool isHostTrusted(String host) {
    return _trustedCertificates.containsKey(host);
  }
}
