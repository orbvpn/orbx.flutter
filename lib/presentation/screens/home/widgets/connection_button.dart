import 'package:flutter/material.dart';

class ConnectionButton extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onPressed;

  const ConnectionButton({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isConnecting ? null : onPressed,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _getGradient(),
          boxShadow: [
            BoxShadow(
              color: _getColor().withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: isConnecting
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                )
              : Icon(
                  isConnected ? Icons.power_off : Icons.power,
                  size: 80,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }

  LinearGradient _getGradient() {
    if (isConnecting) {
      return const LinearGradient(
        colors: [Colors.orange, Colors.deepOrange],
      );
    }
    if (isConnected) {
      return const LinearGradient(
        colors: [Colors.green, Colors.lightGreen],
      );
    }
    return const LinearGradient(
      colors: [Colors.blue, Colors.lightBlue],
    );
  }

  Color _getColor() {
    if (isConnecting) return Colors.orange;
    if (isConnected) return Colors.green;
    return Colors.blue;
  }
}
