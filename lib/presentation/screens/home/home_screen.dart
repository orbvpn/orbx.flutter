/// Home Screen
///
/// Main dashboard screen showing VPN connection status and controls.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart'
    as vpn; // ✅ Use prefix to avoid conflict
import '../../providers/server_provider.dart';
import '../../theme/colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/server.dart'; // ✅ Import OrbXServer

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
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, vpn.ConnectionProvider>(
        builder: (context, authProvider, connectionProvider, child) {
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
                                    user?.fullName ?? user?.email ?? 'User',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (user?.hasActiveSubscription == true) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Premium Active',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        // Connection Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(connectionProvider.state)
                                .withOpacity(0.1),
                            border: Border.all(
                              color: _getStatusColor(connectionProvider.state),
                              width: 4,
                            ),
                          ),
                          child: Icon(
                            _getStatusIcon(connectionProvider.state),
                            size: 60,
                            color: _getStatusColor(connectionProvider.state),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Status Text
                        Text(
                          _getStatusText(connectionProvider.state),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),

                        const SizedBox(height: 8),

                        // Server Info (if connected)
                        if (connectionProvider.isConnected &&
                            connectionProvider.currentServer != null)
                          Text(
                            'Connected to ${connectionProvider.currentServer!.name}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                            textAlign: TextAlign.center,
                          )
                        else
                          Text(
                            connectionProvider.isConnecting
                                ? 'Please wait...'
                                : 'Tap connect to secure your connection',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                            textAlign: TextAlign.center,
                          ),

                        const SizedBox(height: 32),

                        // Connect/Disconnect Button
                        ElevatedButton(
                          onPressed: connectionProvider.isConnecting ||
                                  connectionProvider.isDisconnecting
                              ? null
                              : () => _handleConnectionToggle(
                                    context,
                                    authProvider, // ✅ ADD THIS
                                    connectionProvider,
                                  ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 20,
                            ),
                            backgroundColor: connectionProvider.isConnected
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                          child: Text(
                            connectionProvider.isConnecting
                                ? 'Connecting...'
                                : connectionProvider.isDisconnecting
                                    ? 'Disconnecting...'
                                    : connectionProvider.isConnected
                                        ? 'Disconnect'
                                        : 'Connect',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Quick Actions
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _QuickActionCard(
                      icon: Icons.dns_outlined,
                      title: 'Servers',
                      onTap: () {
                        Navigator.pushNamed(context, '/servers');
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.swap_horiz,
                      title: 'Protocols',
                      onTap: () {
                        Navigator.pushNamed(context, '/connection-settings');
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.bar_chart,
                      title: 'Statistics',
                      onTap: () {
                        Navigator.pushNamed(context, '/statistics');
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      onTap: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Logout Button
                OutlinedButton.icon(
                  onPressed: () async {
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
                      // Disconnect VPN first if connected
                      if (connectionProvider.isConnected) {
                        await connectionProvider.disconnect();
                      }

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

  // ✅ FIXED: Handle connection toggle - Added authProvider parameter
  Future<void> _handleConnectionToggle(
    BuildContext context,
    AuthProvider authProvider, // ✅ ADD THIS
    vpn.ConnectionProvider connectionProvider,
  ) async {
    if (connectionProvider.isConnected) {
      // Disconnect
      await connectionProvider.disconnect();
    } else {
      // Connect - need to select server first
      final serverProvider = context.read<ServerProvider>();

      // Load servers if not already loaded
      if (serverProvider.servers.isEmpty) {
        await serverProvider.loadServers();
      }

      // Get best server
      OrbXServer? server;
      try {
        server = await context.read<ServerProvider>().getBestServer();
      } catch (e) {
        // Fallback to first available server
        if (serverProvider.servers.isNotEmpty) {
          server = serverProvider.servers.first;
        }
      }

      if (server == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('No servers available. Please check your connection.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // ✅ FIX: Get auth token
      final authToken = authProvider.authToken;

      if (authToken == null || authToken.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please login again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // ✅ FIX: Connect to server with auth token
      await connectionProvider.connect(
        server: server,
        authToken: authToken,
      );
    }
  }

  // Helper methods for UI
  Color _getStatusColor(vpn.ConnectionState state) {
    switch (state) {
      case vpn.ConnectionState.connected:
        return AppColors.success;
      case vpn.ConnectionState.connecting:
      case vpn.ConnectionState.disconnecting:
        return AppColors.warning;
      case vpn.ConnectionState.error:
        return AppColors.error;
      case vpn.ConnectionState.disconnected:
      default:
        return AppColors.idle;
    }
  }

  IconData _getStatusIcon(vpn.ConnectionState state) {
    switch (state) {
      case vpn.ConnectionState.connected:
        return Icons.shield;
      case vpn.ConnectionState.connecting:
      case vpn.ConnectionState.disconnecting:
        return Icons.sync;
      case vpn.ConnectionState.error:
        return Icons.error_outline;
      case vpn.ConnectionState.disconnected:
      default:
        return Icons.shield_outlined;
    }
  }

  String _getStatusText(vpn.ConnectionState state) {
    switch (state) {
      case vpn.ConnectionState.connected:
        return 'Connected';
      case vpn.ConnectionState.connecting:
        return 'Connecting...';
      case vpn.ConnectionState.disconnecting:
        return 'Disconnecting...';
      case vpn.ConnectionState.error:
        return 'Connection Error';
      case vpn.ConnectionState.disconnected:
      default:
        return 'Not Connected';
    }
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
