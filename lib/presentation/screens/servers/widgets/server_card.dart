import 'package:flutter/material.dart';
import '../../../../data/models/server.dart';

class ServerCard extends StatelessWidget {
  final OrbXServer server;
  final VoidCallback onTap;

  const ServerCard({
    super.key, // Changed from Key? key
    required this.server,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: server.isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Country flag
              Text(
                _getFlagEmoji(server.countryCode),
                style: const TextStyle(fontSize: 32),
              ),

              const SizedBox(width: 16),

              // Server info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      server.location,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    // Protocol chips
                    Wrap(
                      spacing: 4,
                      children: server.protocols.take(3).map((protocol) {
                        return Chip(
                          label: Text(
                            _getProtocolName(
                                protocol), // Changed to helper method
                            style: const TextStyle(fontSize: 10),
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Latency & Load
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Latency
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _getLatencyColor(server.latencyMs).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${server.latencyMs ?? 0}ms',
                      style: TextStyle(
                        color: _getLatencyColor(server.latencyMs),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Load indicator
                  Text(
                    '${server.loadPercentage.toInt()}% load',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to safely get protocol name
  String _getProtocolName(dynamic protocol) {
    if (protocol == null) return 'Unknown';
    // If it has a name property, use it
    try {
      return protocol.name ?? 'Unknown';
    } catch (e) {
      // Fallback to toString
      return protocol.toString().split('.').last;
    }
  }

  String _getFlagEmoji(String countryCode) {
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
      'RU': '🇷🇺',
      'CN': '🇨🇳',
      'AE': '🇦🇪',
      'CH': '🇨🇭',
      'SE': '🇸🇪',
      'NO': '🇳🇴',
      'IE': '🇮🇪',
      'HK': '🇭🇰',
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
