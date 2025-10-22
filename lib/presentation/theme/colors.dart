/// App Color Palette
///
/// Defines all colors used throughout the application for consistency.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Private constructor

  // ==========================================
  // Primary Brand Colors
  // ==========================================

  /// Main brand color (OrbVPN Blue)
  static const Color primary = Color(0xFF2196F3); // Blue
  static const Color primaryDark =
      Color(0xFF1976D2); // Darker blue for dark mode
  static const Color primaryLight = Color(0xFF64B5F6); // Lighter blue

  /// Secondary brand color (accent)
  static const Color secondary = Color(0xFF00BCD4); // Cyan
  static const Color secondaryDark = Color(0xFF0097A7); // Darker cyan
  static const Color secondaryLight = Color(0xFF4DD0E1); // Lighter cyan

  // ==========================================
  // Status Colors
  // ==========================================

  /// Success color (green)
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color successDark = Color(0xFF388E3C);

  /// Warning color (orange/amber)
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFF57C00);

  /// Error color (red)
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFE57373);
  static const Color errorDark = Color(0xFFD32F2F);

  /// Info color (blue)
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFF64B5F6);
  static const Color infoDark = Color(0xFF1976D2);

  // ==========================================
  // Connection Status Colors
  // ==========================================

  /// Connected (green)
  static const Color connected = Color(0xFF4CAF50);

  /// Connecting (orange/yellow)
  static const Color connecting = Color(0xFFFF9800);

  /// Disconnected (red)
  static const Color disconnected = Color(0xFFF44336);

  /// Idle (grey)
  static const Color idle = Color(0xFF9E9E9E);

  // ==========================================
  // Light Theme Colors
  // ==========================================

  /// Background
  static const Color backgroundLight = Color(0xFFF5F5F5);

  /// Surface (cards, dialogs)
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);

  /// Divider
  static const Color divider = Color(0xFFE0E0E0);

  // ==========================================
  // Dark Theme Colors
  // ==========================================

  /// Background
  static const Color backgroundDark = Color(0xFF121212);

  /// Surface (cards, dialogs)
  static const Color surfaceDark = Color(0xFF1E1E1E);

  /// Text colors
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textDisabledDark = Color(0xFF6E6E6E);

  /// Divider
  static const Color dividerDark = Color(0xFF2E2E2E);

  // ==========================================
  // Gradient Colors
  // ==========================================

  /// Primary gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Secondary gradient
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Success gradient
  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Background gradient (for splash, onboarding)
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ==========================================
  // Protocol Mimicry Colors
  // ==========================================

  /// Different colors for each protocol type (for visualization)
  static const Color protocolTeams = Color(0xFF6264A7); // Microsoft purple
  static const Color protocolDrive = Color(0xFF4285F4); // Google blue
  static const Color protocolMeet = Color(0xFF00897B); // Google teal
  static const Color protocolZoom = Color(0xFF2D8CFF); // Zoom blue
  static const Color protocolShaparak = Color(0xFFE91E63); // Pink
  static const Color protocolDNS = Color(0xFF9C27B0); // Purple
  static const Color protocolFragmented = Color(0xFFFF5722); // Deep orange
  static const Color protocolTLS = Color(0xFF009688); // Teal
  static const Color protocolHTTP2 = Color(0xFF3F51B5); // Indigo
  static const Color protocolWebSocket = Color(0xFFCDDC39); // Lime

  // ==========================================
  // Chart Colors (for statistics)
  // ==========================================

  static const List<Color> chartColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFF44336), // Red
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF795548), // Brown
  ];

  // ==========================================
  // Opacity Variants
  // ==========================================

  /// Get color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  /// Semi-transparent overlay
  static Color get overlay => Colors.black.withOpacity(0.5);

  /// Light overlay
  static Color get overlayLight => Colors.black.withOpacity(0.2);

  /// Dark overlay
  static Color get overlayDark => Colors.black.withOpacity(0.7);
}
