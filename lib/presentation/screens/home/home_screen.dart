import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import '../../../core/constants/mimicry_protocols.dart'; // ADD THIS
import 'widgets/connection_button.dart';
import 'widgets/status_indicator.dart';
import 'widgets/quick_stats.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<ConnectionProvider>(
          builder: (context, connection, _) {
            return Column(
              children: [
                // App Bar
                _buildAppBar(context),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Connection Status Indicator
                        StatusIndicator(
                          isConnected: connection.isConnected,
                          isConnecting: connection.isConnecting,
                        ),

                        const SizedBox(height: 40),

                        // Main Connect Button
                        ConnectionButton(
                          isConnected: connection.isConnected,
                          isConnecting: connection.isConnecting,
                          onPressed: () =>
                              _handleConnectionToggle(context, connection),
                        ),

                        const SizedBox(height: 40),

                        // Server Info Card
                        if (connection.currentServer != null)
                          _buildServerInfoCard(context, connection),

                        const SizedBox(height: 24),

                        // Quick Stats
                        if (connection.isConnected)
                          QuickStats(
                            bytesSent: connection.bytesSent,
                            bytesReceived: connection.bytesReceived,
                            duration: connection.connectionDuration,
                          ),

                        const SizedBox(height: 24),

                        // Protocol Selector
                        if (connection.isConnected)
                          _buildProtocolSelector(context, connection),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Image.asset('assets/images/logo.png', height: 40),

          Row(
            children: [
              // Servers button
              IconButton(
                icon: const Icon(Icons.dns_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, '/servers');
                },
              ),

              // Settings button
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServerInfoCard(
    BuildContext context,
    ConnectionProvider connection,
  ) {
    final server = connection.currentServer!;
    final protocol = connection.currentProtocol;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Country flag
                Text(
                  _getFlagEmoji(server.countryCode),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        server.location,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Change server button
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/servers');
                  },
                  child: const Text('Change'),
                ),
              ],
            ),

            const Divider(height: 24),

            // Protocol info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protocol',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      protocol?.name ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Latency',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${server.latencyMs ?? 0}ms',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _getLatencyColor(server.latencyMs),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolSelector(
    BuildContext context,
    ConnectionProvider connection,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Protocol Disguise',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MimicryProtocol.values.map((protocol) {
                final isSelected = protocol == connection.currentProtocol;
                return ChoiceChip(
                  label: Text(protocol.name),
                  selected: isSelected,
                  onSelected: (_) {
                    connection.switchProtocol(protocol);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConnectionToggle(
    BuildContext context,
    ConnectionProvider connection,
  ) async {
    await connection.toggleConnection();

    if (connection.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(connection.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getFlagEmoji(String countryCode) {
    // Convert country code to flag emoji
    // This is a simplified version
    final Map<String, String> flags = {
      'US': '🇺🇸',
      'GB': '🇬🇧',
      'DE': '🇩🇪',
      'FR': '🇫🇷',
      'NL': '🇳🇱',
      'CA': '🇨🇦',
      'AU': '🇦🇺',
      'JP': '🇯🇵',
      'SG': '🇸🇬',
      'IN': '🇮🇳',
      'IR': '🇮🇷',
      'BR': '🇧🇷',
      // Add more as needed
    };
    return flags[countryCode] ?? '🌍';
  }

  Color _getLatencyColor(int? latency) {
    if (latency == null) return Colors.grey;
    if (latency < 100) return Colors.green;
    if (latency < 300) return Colors.orange;
    return Colors.red;
  }
}
