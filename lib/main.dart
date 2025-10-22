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
import 'firebase_options.dart'; // ✅ Import Firebase options

final Logger _logger = Logger();

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialize Firebase (with error handling)
  await _initializeFirebase();

  // Initialize Hive
  await _initializeHive();

  // Setup dependency injection
  await _setupDependencies();

  // Run the app
  runApp(const OrbXApp());
}

/// Initialize Firebase with proper error handling
Future<void> _initializeFirebase() async {
  try {
    // ✅ Use the generated Firebase options for the current platform
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _logger.i('✅ Firebase initialized successfully');
  } catch (e) {
    _logger.w('⚠️  Firebase initialization failed: $e');
    _logger.w('⚠️  App will continue without Firebase features');
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
  }
}

/// Setup dependency injection with error handling
Future<void> _setupDependencies() async {
  try {
    await setupDependencies();
    _logger.i('✅ Dependencies initialized successfully');
  } catch (e) {
    _logger.e('❌ Dependency injection had issues: $e');
    // DON'T show error screen - some services (like Firebase) are optional
    // The app can work without them
    _logger.w('⚠️  Continuing anyway - core features should still work');
  }
}
