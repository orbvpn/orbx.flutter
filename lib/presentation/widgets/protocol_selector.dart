// lib/presentation/widgets/protocol_selector.dart
// Protocol selector widget for choosing mimicry protocol

import 'package:flutter/material.dart';

class ProtocolSelector extends StatelessWidget {
  final String selectedProtocol;
  final Function(String) onProtocolChanged;

  const ProtocolSelector({
    super.key,
    required this.selectedProtocol,
    required this.onProtocolChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Protocol Mimicry',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose which app your VPN traffic should look like',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildProtocolChip('teams', 'Microsoft Teams', Icons.groups),
                _buildProtocolChip('google', 'Google Workspace', Icons.apps),
                _buildProtocolChip(
                    'shaparak', 'Shaparak Banking', Icons.account_balance),
                _buildProtocolChip('zoom', 'Zoom', Icons.video_call),
                _buildProtocolChip('doh', 'DNS over HTTPS', Icons.dns),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolChip(String protocol, String label, IconData icon) {
    final isSelected = selectedProtocol == protocol;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        if (selected) {
          onProtocolChanged(protocol);
        }
      },
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
    );
  }
}
