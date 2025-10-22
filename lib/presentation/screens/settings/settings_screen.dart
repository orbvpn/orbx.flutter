import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../../core/constants/mimicry_protocols.dart';
import 'widgets/setting_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoConnect = false;
  bool _killSwitch = false;
  MimicryProtocol _defaultProtocol = MimicryProtocol.teams;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account Section
          _buildSectionHeader('Account'),
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final user = authProvider.currentUser;
              return Column(
                children: [
                  SettingTile(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    subtitle: user?.email ?? 'Not logged in',
                    onTap: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                  SettingTile(
                    icon: Icons.subscriptions_outlined,
                    title: 'Subscription',
                    subtitle: user?.subscription?.planName ?? 'Free',
                    onTap: () {
                      Navigator.pushNamed(context, '/subscription');
                    },
                  ),
                ],
              );
            },
          ),

          const Divider(),

          // Connection Section
          _buildSectionHeader('Connection'),

          SwitchListTile(
            secondary: const Icon(Icons.play_arrow),
            title: const Text('Auto-connect on startup'),
            subtitle: const Text('Automatically connect when app starts'),
            value: _autoConnect,
            onChanged: (value) {
              setState(() {
                _autoConnect = value;
              });
              // TODO: Save preference
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.security),
            title: const Text('Kill Switch'),
            subtitle: const Text('Block internet if VPN disconnects'),
            value: _killSwitch,
            onChanged: (value) {
              setState(() {
                _killSwitch = value;
              });
              // TODO: Save preference
            },
          ),

          SettingTile(
            icon: Icons.sync_alt,
            title: 'Default Protocol',
            subtitle: _defaultProtocol.name,
            onTap: () => _showProtocolSelector(),
          ),

          const Divider(),

          // Appearance Section
          _buildSectionHeader('Appearance'),

          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return SettingTile(
                icon: Icons.brightness_6,
                title: 'Theme',
                subtitle: themeProvider.isDarkMode ? 'Dark' : 'Light',
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                ),
                onTap: () {
                  themeProvider.toggleTheme();
                },
              );
            },
          ),

          SettingTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: _selectedLanguage,
            onTap: () => _showLanguageSelector(),
          ),

          const Divider(),

          // Advanced Section
          _buildSectionHeader('Advanced'),

          SettingTile(
            icon: Icons.dns,
            title: 'DNS Settings',
            subtitle: 'Configure custom DNS servers',
            onTap: () {
              Navigator.pushNamed(context, '/dns-settings');
            },
          ),

          SettingTile(
            icon: Icons.speed,
            title: 'Split Tunneling',
            subtitle: 'Exclude apps from VPN',
            onTap: () {
              Navigator.pushNamed(context, '/split-tunneling');
            },
          ),

          const Divider(),

          // About Section
          _buildSectionHeader('About'),

          SettingTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: '1.0.0 (Build 1)',
            onTap: () {},
          ),

          SettingTile(
            icon: Icons.description_outlined,
            title: 'Privacy Policy',
            onTap: () {
              Navigator.pushNamed(context, '/privacy-policy');
            },
          ),

          SettingTile(
            icon: Icons.gavel_outlined,
            title: 'Terms of Service',
            onTap: () {
              Navigator.pushNamed(context, '/terms');
            },
          ),

          SettingTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              Navigator.pushNamed(context, '/support');
            },
          ),

          const Divider(),

          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _handleLogout(),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _showProtocolSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: MimicryProtocol.values.map((protocol) {
            return ListTile(
              leading: Icon(
                _defaultProtocol == protocol
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(protocol.name),
              subtitle: Text(protocol.description),
              onTap: () {
                setState(() {
                  _defaultProtocol = protocol;
                });
                Navigator.pop(context);
                // TODO: Save preference
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showLanguageSelector() {
    final languages = ['English', 'فارسی', 'العربية', 'Русский'];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: languages.map((language) {
            return ListTile(
              leading: Icon(
                _selectedLanguage == language
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(language),
              onTap: () {
                setState(() {
                  _selectedLanguage = language;
                });
                Navigator.pop(context);
                // TODO: Save preference and update locale
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
