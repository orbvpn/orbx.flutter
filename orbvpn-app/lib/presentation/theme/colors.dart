import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF1E3A8A); // Deep Blue
  static const Color accent = Color(0xFF06B6D4); // Cyan

  // Status colors
  static const Color success = Color(0xFF10B981); // Green
  static const Color warning = Color(0xFFF59E0B); // Orange
  static const Color error = Color(0xFFEF4444); // Red

  // Light theme
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color surfaceLight = Colors.white;
  static const Color textDark = Color(0xFF111827);

  // Dark theme
  static const Color backgroundDark = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color textLight = Color(0xFFF9FAFB);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
