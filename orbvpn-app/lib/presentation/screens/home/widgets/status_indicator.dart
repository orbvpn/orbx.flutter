import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;

  const StatusIndicator({
    super.key,
    required this.isConnected,
    required this.isConnecting,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getColor(),
            boxShadow: [
              BoxShadow(
                color: _getColor().withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(_getStatusText(), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          _getSubtitleText(),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Color _getColor() {
    if (isConnecting) return Colors.orange;
    if (isConnected) return Colors.green;
    return Colors.red;
  }

  String _getStatusText() {
    if (isConnecting) return 'Connecting...';
    if (isConnected) return 'Connected';
    return 'Disconnected';
  }

  String _getSubtitleText() {
    if (isConnecting) return 'Establishing secure tunnel';
    if (isConnected) return 'Your connection is secure and private';
    return 'Tap to connect to VPN';
  }
}
