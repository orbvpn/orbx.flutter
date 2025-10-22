import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/vpn_protocols.dart';
import '../../../core/constants/mimicry_protocols.dart';
import '../../../core/constants/mimicry_mode.dart';
import '../../providers/connection_settings_provider.dart';

class ConnectionSettingsScreen extends StatelessWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Settings'),
      ),
      body: Consumer<ConnectionSettingsProvider>(
        builder: (context, settings, child) {
          if (settings.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Card
              Card(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Current Configuration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        settings.getSummaryString(),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // VPN Protocol Section
              _buildSectionHeader(context, 'VPN Protocol'),
              _buildVpnProtocolCard(context, settings),

              const SizedBox(height: 24),

              // Mimicry Section
              _buildSectionHeader(context, 'Traffic Disguise'),
              _buildMimicryModeCard(context, settings),

              if (settings.mimicryMode == MimicryMode.manual) ...[
                const SizedBox(height: 16),
                _buildManualMimicrySelector(context, settings),
              ],

              if (settings.mimicryMode == MimicryMode.auto) ...[
                const SizedBox(height: 16),
                _buildAutoMimicryInfo(context, settings),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildVpnProtocolCard(
    BuildContext context,
    ConnectionSettingsProvider settings,
  ) {
    return Card(
      child: Column(
        children: VPNProtocol.values.map((protocol) {
          final isSelected = settings.vpnProtocol == protocol;
          final isAvailable = protocol.isAvailable;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).primaryColor
                  : (isAvailable ? Colors.grey[300] : Colors.grey[200]),
              child: Icon(
                isSelected
                    ? Icons.check
                    : (isAvailable ? Icons.vpn_lock : Icons.lock),
                color: isSelected
                    ? Colors.white
                    : (isAvailable ? Colors.grey[600] : Colors.grey[400]),
              ),
            ),
            title: Row(
              children: [
                Text(
                  protocol.name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isAvailable ? null : Colors.grey,
                  ),
                ),
                if (!isAvailable) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              protocol.description,
              style: TextStyle(
                fontSize: 13,
                color: isAvailable ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
            enabled: isAvailable,
            onTap: isAvailable ? () => settings.setVpnProtocol(protocol) : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMimicryModeCard(
    BuildContext context,
    ConnectionSettingsProvider settings,
  ) {
    return Card(
      child: Column(
        children: MimicryMode.values.map((mode) {
          final isSelected = settings.mimicryMode == mode;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300],
              child: Icon(
                mode == MimicryMode.auto ? Icons.auto_awesome : Icons.touch_app,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
            title: Text(
              mode.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              mode.description,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle,
                    color: Theme.of(context).primaryColor)
                : null,
            onTap: () => settings.setMimicryMode(mode),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildManualMimicrySelector(
    BuildContext context,
    ConnectionSettingsProvider settings,
  ) {
    return Card(
      child: Column(
        children: MimicryProtocol.values.map((protocol) {
          final isSelected = settings.selectedMimicry == protocol;

          return ListTile(
            leading: Icon(
              _getMimicryIcon(protocol),
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600],
            ),
            title: Text(
              protocol.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              protocol.description,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle,
                    color: Theme.of(context).primaryColor)
                : null,
            onTap: () => settings.setManualMimicry(protocol),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAutoMimicryInfo(
    BuildContext context,
    ConnectionSettingsProvider settings,
  ) {
    final detected = settings.autoDetectedMimicry;

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Text(
                  'Auto-Detection Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (detected != null) ...[
              Text(
                'Currently using: ${detected.name}',
                style: TextStyle(color: Colors.blue[900]),
              ),
              const SizedBox(height: 8),
              Text(
                detected.description,
                style: TextStyle(fontSize: 13, color: Colors.blue[700]),
              ),
            ] else ...[
              Text(
                'Best mimicry will be detected when you connect to a server.',
                style: TextStyle(fontSize: 13, color: Colors.blue[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getMimicryIcon(MimicryProtocol protocol) {
    switch (protocol) {
      case MimicryProtocol.teams:
        return Icons.chat_bubble_outline;
      case MimicryProtocol.shaparak:
        return Icons.account_balance;
      case MimicryProtocol.doh:
        return Icons.dns;
      case MimicryProtocol.https:
        return Icons.lock;
      case MimicryProtocol.google:
        return Icons.workspace_premium;
      case MimicryProtocol.zoom:
        return Icons.video_call;
      case MimicryProtocol.facetime:
        return Icons.videocam;
      case MimicryProtocol.vk:
        return Icons.group;
      case MimicryProtocol.yandex:
        return Icons.search;
      case MimicryProtocol.wechat:
        return Icons.message;
    }
  }
}
