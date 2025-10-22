/// Login Screen
///
/// Allows users to log in with email and password.
/// Includes validation and error handling.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/constants/app_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Logger _logger = Logger();

  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    _logger.i('Attempting login for: $email');

    // Perform login
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppConstants.loginSuccessMessage),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate to home
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Error message is already handled by AuthProvider
      // Show in SnackBar
      final error = authProvider.errorMessage ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _navigateToRegister() {
    // TODO: Navigate to register screen (to be implemented)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registration screen coming soon!'),
      ),
    );
  }

  void _navigateToForgotPassword() {
    // TODO: Navigate to forgot password screen (to be implemented)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset coming soon!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),

                // Logo
                Icon(
                  Icons.vpn_lock,
                  size: 80,
                  color: AppColors.primary,
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Sign in to continue',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.validateEmail,
                ),

                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) => Validators.validateRequired(
                    value,
                    fieldName: 'Password',
                  ),
                  onFieldSubmitted: (_) => _handleLogin(),
                ),

                const SizedBox(height: 8),

                // Remember Me & Forgot Password Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Remember Me Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                        const Text('Remember me'),
                      ],
                    ),

                    // Forgot Password Button
                    TextButton(
                      onPressed: _navigateToForgotPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Login Button
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (authProvider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    return ElevatedButton(
                      onPressed: _handleLogin,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('Sign In'),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.divider)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.divider)),
                  ],
                ),

                const SizedBox(height: 16),

                // Register Button
                OutlinedButton(
                  onPressed: _navigateToRegister,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Create Account'),
                  ),
                ),

                const SizedBox(height: 24),

                // Terms & Privacy
                Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
