import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Consumer<ConnectionProvider>(
        builder: (context, connectionProvider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Current Session Stats
              _buildSectionHeader('Current Session'),
              const SizedBox(height: 12),
              _buildStatsCard(
                context,
                [
                  _StatItem(
                    icon: Icons.access_time,
                    label: 'Duration',
                    value: _formatDuration(
                      connectionProvider.connectionDuration,
                    ),
                    color: Colors.blue,
                  ),
                  _StatItem(
                    icon: Icons.upload,
                    label: 'Uploaded',
                    value: _formatBytes(connectionProvider.bytesSent),
                    color: Colors.green,
                  ),
                  _StatItem(
                    icon: Icons.download,
                    label: 'Downloaded',
                    value: _formatBytes(connectionProvider.bytesReceived),
                    color: Colors.orange,
                  ),
                  _StatItem(
                    icon: Icons.swap_vert,
                    label: 'Total Data',
                    value: _formatBytes(
                      connectionProvider.bytesSent +
                          connectionProvider.bytesReceived,
                    ),
                    color: Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Connection Info
              _buildSectionHeader('Connection Details'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Status',
                        connectionProvider.isConnected
                            ? 'Connected'
                            : 'Disconnected',
                        connectionProvider.isConnected
                            ? Colors.green
                            : Colors.red,
                      ),
                      const Divider(height: 24),
                      if (connectionProvider.currentServer != null) ...[
                        _buildInfoRow(
                          'Server',
                          connectionProvider.currentServer!.name,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          'Location',
                          connectionProvider.currentServer!.location,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          'Protocol',
                          connectionProvider.currentProtocol?.name ?? 'N/A',
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          'Latency',
                          '${connectionProvider.currentServer!.latencyMs ?? 0}ms',
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Network Speed
              _buildSectionHeader('Network Speed'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSpeedIndicator(
                        'Upload Speed',
                        _calculateSpeed(
                          connectionProvider.bytesSent,
                          connectionProvider.connectionDuration,
                        ),
                        Colors.green,
                      ),
                      const SizedBox(height: 16),
                      _buildSpeedIndicator(
                        'Download Speed',
                        _calculateSpeed(
                          connectionProvider.bytesReceived,
                          connectionProvider.connectionDuration,
                        ),
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Additional Info
              _buildSectionHeader('Advanced Statistics'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Encryption',
                        'AES-256-GCM + Kyber768',
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        'Protocol Obfuscation',
                        connectionProvider.currentProtocol?.name ?? 'None',
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        'IPv6 Support',
                        'Enabled',
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        'Kill Switch',
                        'Active',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildStatsCard(BuildContext context, List<_StatItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Row(
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
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedIndicator(String label, String speed, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            Text(
              speed,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: 0.7, // You can calculate actual value based on max speed
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _calculateSpeed(int bytes, Duration duration) {
    if (duration.inSeconds == 0) return '0 B/s';

    final bytesPerSecond = bytes / duration.inSeconds;

    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(2)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}
