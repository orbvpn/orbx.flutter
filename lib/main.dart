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
import 'core/services/notification_service.dart';

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
    await Firebase.initializeApp();
    _logger.i('✅ Firebase initialized successfully');
  } catch (e) {
    _logger.w('⚠️  Firebase initialization failed: $e');
    _logger.w('App will continue without Firebase features');
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
    _logger.e('❌ CRITICAL: Dependency injection failed: $e');
    _logger.e('Stack trace: ${StackTrace.current}');
    // This is critical - show error dialog and exit gracefully
    runApp(_ErrorApp(error: e.toString()));
    return;
  }
}

/// Error app shown when critical initialization fails
class _ErrorApp extends StatelessWidget {
  final String error;

  const _ErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Initialization Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    SystemNavigator.pop(); // Close app
                  },
                  child: const Text('Close App'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
