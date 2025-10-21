#!/usr/bin/env bash
set -euo pipefail

# orbvpn/orbx Flutter scaffolder
# Creates the directories & placeholder files per the provided spec.
# Usage: ./scaffold_orbx.sh [TARGET_DIR] [--force]

TARGET_DIR="${1:-./orbvpn-app}"
FORCE="${2:-}"

overwrite_ok=false
if [[ "${FORCE}" == "--force" ]]; then
	overwrite_ok=true
fi

# Create a file with content, safely
write_file() {
	local path="$1"
	shift
	local content="$*"

	if [[ -f "$path" && $overwrite_ok == false ]]; then
		echo "• Skipping existing file: $path"
		return
	fi

	mkdir -p "$(dirname "$path")"
	printf "%s\n" "$content" >"$path"
	echo "✓ Wrote: $path"
}

# Create just an empty (or comment-only) file if missing
touch_file() {
	local path="$1"
	if [[ -f "$path" && $overwrite_ok == false ]]; then
		echo "• Skipping existing file: $path"
		return
	fi
	mkdir -p "$(dirname "$path")"
	: >"$path"
	echo "✓ Touched: $path"
}

echo "Scaffolding project in: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

# -----------------------------
# lib/ tree
# -----------------------------
# Top-level
write_file "$TARGET_DIR/lib/main.dart" "// main.dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() => runApp(const OrbApp());
"
write_file "$TARGET_DIR/lib/app.dart" "// app.dart
import 'package:flutter/material.dart';

class OrbApp extends StatelessWidget {
  const OrbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrbVPN',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('OrbVPN'))),
    );
  }
}
"

# core/constants
write_file "$TARGET_DIR/lib/core/constants/api_constants.dart" "// OrbNet & OrbX endpoints"
write_file "$TARGET_DIR/lib/core/constants/app_constants.dart" "// App-wide constants"
write_file "$TARGET_DIR/lib/core/constants/mimicry_protocols.dart" "// All 10 protocols"

# core/services
write_file "$TARGET_DIR/lib/core/services/wireguard_service.dart" "// WireGuard connection management"
write_file "$TARGET_DIR/lib/core/services/mimicry_manager.dart" "// Protocol selection & switching"
write_file "$TARGET_DIR/lib/core/services/orbx_client.dart" "// HTTP client for OrbX servers"
write_file "$TARGET_DIR/lib/core/services/network_analyzer.dart" "// Latency testing"
write_file "$TARGET_DIR/lib/core/services/notification_service.dart" "// FCM handling"
write_file "$TARGET_DIR/lib/core/services/logger_service.dart" "// Logging"

# core/utils
write_file "$TARGET_DIR/lib/core/utils/crypto_helper.dart" "// WireGuard key generation"
write_file "$TARGET_DIR/lib/core/utils/preferences_helper.dart" "// SharedPreferences wrapper"
write_file "$TARGET_DIR/lib/core/utils/validators.dart" "// Input validation"
write_file "$TARGET_DIR/lib/core/utils/extensions.dart" "// Dart extensions"

# core/di
write_file "$TARGET_DIR/lib/core/di/injection.dart" "// Dependency injection setup"

# core/platform
write_file "$TARGET_DIR/lib/core/platform/wireguard_channel.dart" "// Method channel interface"
write_file "$TARGET_DIR/lib/core/platform/platform_info.dart" "// Platform detection"

# data/models
for f in user server connection wireguard_config mimicry_protocol usage_stats auth_response; do
	write_file "$TARGET_DIR/lib/data/models/$f.dart" "// $f model"
done

# data/repositories
write_file "$TARGET_DIR/lib/data/repositories/auth_repository.dart" "// Authentication logic"
write_file "$TARGET_DIR/lib/data/repositories/server_repository.dart" "// Server management"
write_file "$TARGET_DIR/lib/data/repositories/connection_repository.dart" "// Connection management"
write_file "$TARGET_DIR/lib/data/repositories/stats_repository.dart" "// Usage statistics"

# data/datasources
write_file "$TARGET_DIR/lib/data/datasources/local/local_storage.dart" "// Local data storage"
write_file "$TARGET_DIR/lib/data/datasources/local/cache_manager.dart" "// Caching"
write_file "$TARGET_DIR/lib/data/datasources/remote/graphql_api.dart" "// OrbNet GraphQL API"
write_file "$TARGET_DIR/lib/data/datasources/remote/orbx_api.dart" "// OrbX HTTP API"

# data/api
write_file "$TARGET_DIR/lib/data/api/graphql/client.dart" "// GraphQL client setup"
write_file "$TARGET_DIR/lib/data/api/graphql/queries.dart" "// GraphQL queries"
write_file "$TARGET_DIR/lib/data/api/graphql/mutations.dart" "// GraphQL mutations"
write_file "$TARGET_DIR/lib/data/api/http/dio_client.dart" "// Dio HTTP client"

# presentation/screens
write_file "$TARGET_DIR/lib/presentation/screens/splash/splash_screen.dart" "// Splash"
write_file "$TARGET_DIR/lib/presentation/screens/auth/login_screen.dart" "// Login"
write_file "$TARGET_DIR/lib/presentation/screens/auth/register_screen.dart" "// Register"
write_file "$TARGET_DIR/lib/presentation/screens/auth/forgot_password_screen.dart" "// Forgot Password"
write_file "$TARGET_DIR/lib/presentation/screens/home/home_screen.dart" "// Main VPN control"

# presentation/screens/home/widgets
write_file "$TARGET_DIR/lib/presentation/screens/home/widgets/connection_button.dart" "// Connection button"
write_file "$TARGET_DIR/lib/presentation/screens/home/widgets/status_indicator.dart" "// Status indicator"
write_file "$TARGET_DIR/lib/presentation/screens/home/widgets/quick_stats.dart" "// Quick stats"

# servers
write_file "$TARGET_DIR/lib/presentation/screens/servers/server_list_screen.dart" "// Server list"
write_file "$TARGET_DIR/lib/presentation/screens/servers/server_detail_screen.dart" "// Server detail"
write_file "$TARGET_DIR/lib/presentation/screens/servers/widgets/server_card.dart" "// Server card"
write_file "$TARGET_DIR/lib/presentation/screens/servers/widgets/server_filter.dart" "// Server filter"

# protocols
write_file "$TARGET_DIR/lib/presentation/screens/protocols/protocol_selector_screen.dart" "// Protocol selector"
write_file "$TARGET_DIR/lib/presentation/screens/protocols/widgets/protocol_card.dart" "// Protocol card"

# statistics
write_file "$TARGET_DIR/lib/presentation/screens/statistics/stats_screen.dart" "// Stats"
write_file "$TARGET_DIR/lib/presentation/screens/statistics/widgets/usage_chart.dart" "// Usage chart"
write_file "$TARGET_DIR/lib/presentation/screens/statistics/widgets/session_history.dart" "// Session history"

# settings
write_file "$TARGET_DIR/lib/presentation/screens/settings/settings_screen.dart" "// Settings"
write_file "$TARGET_DIR/lib/presentation/screens/settings/widgets/setting_tile.dart" "// Setting tile"
write_file "$TARGET_DIR/lib/presentation/screens/settings/widgets/theme_selector.dart" "// Theme selector"

# profile
write_file "$TARGET_DIR/lib/presentation/screens/profile/profile_screen.dart" "// Profile"

# presentation/providers
write_file "$TARGET_DIR/lib/presentation/providers/auth_provider.dart" "// Authentication state"
write_file "$TARGET_DIR/lib/presentation/providers/connection_provider.dart" "// Connection state"
write_file "$TARGET_DIR/lib/presentation/providers/server_provider.dart" "// Server list state"
write_file "$TARGET_DIR/lib/presentation/providers/protocol_provider.dart" "// Protocol selection state"
write_file "$TARGET_DIR/lib/presentation/providers/theme_provider.dart" "// Theme state"

# presentation/widgets
write_file "$TARGET_DIR/lib/presentation/widgets/common/custom_button.dart" "// Custom button"
write_file "$TARGET_DIR/lib/presentation/widgets/common/custom_text_field.dart" "// Custom text field"
write_file "$TARGET_DIR/lib/presentation/widgets/common/loading_indicator.dart" "// Loading indicator"
write_file "$TARGET_DIR/lib/presentation/widgets/common/error_widget.dart" "// Error widget"

write_file "$TARGET_DIR/lib/presentation/widgets/vpn/connection_timer.dart" "// Connection timer"
write_file "$TARGET_DIR/lib/presentation/widgets/vpn/data_counter.dart" "// Data counter"
write_file "$TARGET_DIR/lib/presentation/widgets/vpn/latency_indicator.dart" "// Latency indicator"

# presentation/theme
write_file "$TARGET_DIR/lib/presentation/theme/app_theme.dart" "// Theme configuration"
write_file "$TARGET_DIR/lib/presentation/theme/colors.dart" "// Color palette"
write_file "$TARGET_DIR/lib/presentation/theme/text_styles.dart" "// Text styles"

# l10n
write_file "$TARGET_DIR/l10n/app_en.arb" "{\n  \"appTitle\": \"OrbVPN\"\n}\n"
write_file "$TARGET_DIR/l10n/app_fa.arb" "{\n  \"appTitle\": \"اورب وی‌پی‌ان\"\n}\n"
write_file "$TARGET_DIR/l10n/app_ar.arb" "{\n  \"appTitle\": \"أورب في بي إن\"\n}\n"
write_file "$TARGET_DIR/l10n/app_ru.arb" "{\n  \"appTitle\": \"ОрбВПН\"\n}\n"

# -----------------------------
# Platform-specific code trees
# -----------------------------

# ANDROID
write_file "$TARGET_DIR/android/app/src/main/kotlin/com/orbvpn/orbx/MainActivity.kt" "package com.orbvpn.orbx\n\nclass MainActivity {}\n"
write_file "$TARGET_DIR/android/app/src/main/kotlin/com/orbvpn/orbx/VpnService.kt" "package com.orbvpn.orbx\n\nclass VpnService {}\n"
write_file "$TARGET_DIR/android/app/src/main/kotlin/com/orbvpn/orbx/WireGuardManager.kt" "package com.orbvpn.orbx\n\nclass WireGuardManager {}\n"
write_file "$TARGET_DIR/android/app/src/main/kotlin/com/orbvpn/orbx/ProtocolHandler.kt" "package com.orbvpn.orbx\n\nclass ProtocolHandler {}\n"
write_file "$TARGET_DIR/android/app/src/main/AndroidManifest.xml" "<manifest package=\"com.orbvpn.orbx\"/>"

# iOS
write_file "$TARGET_DIR/ios/Runner/AppDelegate.swift" "import UIKit\n@UIApplicationMain\nclass AppDelegate: UIResponder, UIApplicationDelegate {}\n"
write_file "$TARGET_DIR/ios/Runner/WireGuardBridge.swift" "import Foundation\nclass WireGuardBridge {}\n"
write_file "$TARGET_DIR/ios/PacketTunnel/PacketTunnelProvider.swift" "import NetworkExtension\nclass PacketTunnelProvider: NEPacketTunnelProvider {}\n"
write_file "$TARGET_DIR/ios/PacketTunnel/WireGuardManager.swift" "import Foundation\nclass WireGuardManager {}\n"
write_file "$TARGET_DIR/ios/PacketTunnel/Info.plist" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict></dict></plist>"

# macOS
write_file "$TARGET_DIR/macos/Runner/WireGuardBridge.swift" "import Foundation\nclass WireGuardBridge {}\n"
write_file "$TARGET_DIR/macos/PacketTunnel/PacketTunnelProvider.swift" "import NetworkExtension\nclass PacketTunnelProvider {}\n"

# Windows
write_file "$TARGET_DIR/windows/runner/wireguard_plugin.cpp" "// Windows WireGuard plugin"
write_file "$TARGET_DIR/windows/runner/vpn_manager.cpp" "// Windows VPN manager"

# Linux
write_file "$TARGET_DIR/linux/wireguard/wireguard_wrapper.c" "/* Linux WireGuard wrapper */"
write_file "$TARGET_DIR/linux/wireguard/tunnel_manager.c" "/* Linux tunnel manager */"

# Housekeeping (gitignore, readme)
write_file "$TARGET_DIR/.gitignore" "# Flutter/Dart\n.dart_tool/\n.build/\n.flutter-plugins*\n.packages\npubspec.lock\n**/build/\n"
write_file "$TARGET_DIR/README.md" "# OrbVPN Scaffold\n\nThis project was scaffolded by scaffold_orbx.sh\n"

echo "✅ Scaffold complete."
