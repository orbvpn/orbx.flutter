import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Wait a bit for splash effect
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user is authenticated
    final authProvider = context.read<AuthProvider>();
    final isAuthenticated = await authProvider.checkAuth();

    if (!mounted) return;

    // Navigate to appropriate screen
    if (isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset('assets/images/logo.png', width: 150, height: 150),

            const SizedBox(height: 24),

            // App name
            const Text(
              'OrbVPN',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Secure. Private. Undetectable.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),

            const SizedBox(height: 48),

            // Loading indicator
            const CircularProgressIndicator(color: Colors.white),
          ],
        )),
      ),
    );
  }
}
