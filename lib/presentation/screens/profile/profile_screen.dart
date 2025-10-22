import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.currentUser;

          if (user == null) {
            return const Center(
              child: Text('Not logged in'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    user.email[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // User info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Email', user.email),
                      if (user.firstName != null)
                        _buildInfoRow('First Name', user.firstName!),
                      if (user.lastName != null)
                        _buildInfoRow('Last Name', user.lastName!),
                      _buildInfoRow('User ID', user.id),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Subscription info
              if (user.subscription != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subscription',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow('Plan', user.subscription!.planName),
                        _buildInfoRow(
                          'Max Devices',
                          user.subscription!.maxDevices.toString(),
                        ),
                        if (user.subscription!.expiryDate != null)
                          _buildInfoRow(
                            'Expires',
                            user.subscription!.expiryDate!,
                          ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Logout button
              ElevatedButton.icon(
                onPressed: () async {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
