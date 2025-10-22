/// OrbVPN - Main Entry Point
///
/// Production-ready initialization with proper error handling and fallbacks.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/config/environment_config.dart';
import 'core/security/certificate_manager.dart';
import 'firebase_options.dart';

final Logger _logger = Logger();

void main() async {
  // Ensure Flutter is initialized FIRST
  WidgetsFlutterBinding.ensureInitialized();

  // Print environment configuration
  _logger.i('🚀 Starting OrbVPN...');
  EnvironmentConfig.printConfig();

  // Set system UI overlay style
  await _configureSystemUI();

  // Initialize core services in order
  await _initializeFirebase();
  await _initializeHive();
  await _initializeCertificateManager();
  await _setupDependencies();

  // Run the app
  _logger.i('✅ All systems initialized - launching app');
  runApp(const OrbXApp());
}

/// Configure system UI (status bar, navigation bar, orientation)
Future<void> _configureSystemUI() async {
  try {
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _logger.i('✅ System UI configured');
  } catch (e) {
    _logger.w('⚠️  System UI configuration failed: $e');
    // Continue anyway - not critical
  }
}

/// Initialize Firebase with proper error handling
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _logger.i('✅ Firebase initialized successfully');
  } catch (e) {
    _logger.w('⚠️  Firebase initialization failed: $e');
    _logger.w('    App will continue without Firebase features');
    // Continue without Firebase - core VPN functionality doesn't depend on it
  }
}

/// Initialize Hive local database
Future<void> _initializeHive() async {
  try {
    await Hive.initFlutter();
    _logger.i('✅ Hive initialized successfully');
  } catch (e) {
    _logger.e('❌ Hive initialization failed: $e');
    // Hive is important but not critical - continue anyway
    _logger.w('    Continuing without local database');
  }
}

/// Initialize Certificate Manager for automatic SSL/TLS security
Future<void> _initializeCertificateManager() async {
  try {
    _logger.i('🔐 Initializing certificate manager...');

    // Configure certificate manager based on environment
    CertificateManager.debugLogging = EnvironmentConfig.enableDebugLogging;

    // Initialize certificate storage
    await CertificateManager.initialize();

    final trustedCount = CertificateManager.getAllTrustedCertificates().length;
    _logger.i('✅ Certificate manager initialized');
    _logger.i('    Trusted certificates: $trustedCount');
    _logger.i('    Environment: ${EnvironmentConfig.environmentName}');
    _logger
        .i('    Trust-On-First-Use: ${EnvironmentConfig.useTrustOnFirstUse}');

    // Log current trusted certificates in debug mode
    if (EnvironmentConfig.enableDebugLogging && trustedCount > 0) {
      _logger.d('📋 Trusted hosts:');
      CertificateManager.getAllTrustedCertificates()
          .forEach((host, fingerprint) {
        _logger.d('    - $host: ${fingerprint.substring(0, 16)}...');
      });
    }
  } catch (e, stackTrace) {
    _logger.e('❌ Certificate manager initialization failed: $e');
    _logger.e('    Stack trace: $stackTrace');
    _logger
        .w('    VPN connections may fail due to certificate validation errors');
    // Continue anyway - the app can still function, but SSL validation might fail
  }
}

/// Setup dependency injection with error handling
Future<void> _setupDependencies() async {
  try {
    _logger.i('⚙️  Setting up dependency injection...');
    await setupDependencies();
    _logger.i('✅ Dependencies initialized successfully');
  } catch (e, stackTrace) {
    _logger.e('❌ Dependency injection setup failed: $e');
    _logger.e('    Stack trace: $stackTrace');
    // DON'T show error screen - some services (like Firebase) are optional
    // The app can work without them
    _logger.w('⚠️  Continuing anyway - core features should still work');
  }
}
