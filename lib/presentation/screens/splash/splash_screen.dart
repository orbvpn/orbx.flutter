/// Splash Screen
///
/// Initial screen shown while app initializes.
/// Checks authentication status and navigates accordingly.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../../core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      _logger.i('Initializing app...');

      // Initialize authentication
      final authProvider = context.read<AuthProvider>();
      await authProvider.initialize();

      // Wait minimum splash duration for branding
      await Future.delayed(AppConstants.splashScreenDuration);

      if (!mounted) return;

      // Navigate based on authentication status
      if (authProvider.isAuthenticated) {
        _logger.i('User authenticated, navigating to home');
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _logger.i('User not authenticated, navigating to login');
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      _logger.e('Error during initialization: $e');

      // On error, show error and navigate to login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Initialization error: $e'),
            backgroundColor: AppColors.error,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Icon(
                Icons.vpn_lock,
                size: 120,
                color: Colors.white,
              ),

              const SizedBox(height: 24),

              // App Name
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 8),

              // Tagline
              Text(
                'Secure. Private. Invisible.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),

              const SizedBox(height: 48),

              // Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
