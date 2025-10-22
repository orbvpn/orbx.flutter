/// Home Screen
///
/// Main dashboard screen showing VPN connection status and controls.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../../core/constants/app_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          // Profile/Settings button
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(
                                user?.fullName.substring(0, 1).toUpperCase() ??
                                    'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    user?.fullName ?? 'User',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (user?.subscription != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Subscription Info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Plan',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    user!.subscription!.planName,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Devices',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    '${user.subscription!.maxDevices} max',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Connection Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Status Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.idle.withOpacity(0.2),
                            border: Border.all(
                              color: AppColors.idle,
                              width: 4,
                            ),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            size: 60,
                            color: AppColors.idle,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Status Text
                        Text(
                          'Not Connected',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Tap connect to secure your connection',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // Connect Button
                        ElevatedButton(
                          onPressed: () {
                            // TODO: Implement connection
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('VPN connection coming soon!'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 20,
                            ),
                          ),
                          child: const Text(
                            'Connect',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Quick Actions
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _QuickActionCard(
                      icon: Icons.dns_outlined,
                      title: 'Servers',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Server list coming soon!')),
                        );
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.bar_chart_outlined,
                      title: 'Statistics',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Statistics coming soon!')),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Logout Button
                OutlinedButton.icon(
                  onPressed: () async {
                    // Show confirmation dialog
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                            ),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true && mounted) {
                      await authProvider.logout();
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    }
                  },
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
