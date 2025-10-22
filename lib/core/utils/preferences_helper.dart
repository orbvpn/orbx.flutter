import 'package:shared_preferences/shared_preferences.dart';
import '../constants/vpn_protocols.dart';
import '../constants/mimicry_protocols.dart';
import '../constants/mimicry_mode.dart';

class PreferencesHelper {
  // Keys
  static const String _keyVpnProtocol = 'vpn_protocol';
  static const String _keyMimicryMode = 'mimicry_mode';
  static const String _keySelectedMimicry = 'selected_mimicry';
  static const String _keyAutoConnect = 'auto_connect';
  static const String _keyKillSwitch = 'kill_switch';

  // VPN Protocol
  static Future<void> saveVpnProtocol(VPNProtocol protocol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVpnProtocol, protocol.name);
  }

  static Future<VPNProtocol> loadVpnProtocol() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyVpnProtocol);

    if (saved != null) {
      try {
        return VPNProtocol.values.firstWhere((p) => p.name == saved);
      } catch (e) {
        return VPNProtocol.wireguard; // Default
      }
    }
    return VPNProtocol.wireguard; // Default
  }

  // Mimicry Mode (Auto or Manual)
  static Future<void> saveMimicryMode(MimicryMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMimicryMode, mode.name);
  }

  static Future<MimicryMode> loadMimicryMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyMimicryMode);

    if (saved != null) {
      try {
        return MimicryMode.values.firstWhere((m) => m.name == saved);
      } catch (e) {
        return MimicryMode.auto; // Default to auto
      }
    }
    return MimicryMode.auto; // Default to auto
  }

  // Selected Mimicry (only used in Manual mode)
  static Future<void> saveSelectedMimicry(MimicryProtocol protocol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedMimicry, protocol.name);
  }

  static Future<MimicryProtocol> loadSelectedMimicry() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keySelectedMimicry);

    if (saved != null) {
      try {
        return MimicryProtocol.values.firstWhere((p) => p.name == saved);
      } catch (e) {
        return MimicryProtocol.teams;
      }
    }
    return MimicryProtocol.teams;
  }

  // Auto-connect
  static Future<void> saveAutoConnect(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoConnect, enabled);
  }

  static Future<bool> loadAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoConnect) ?? false;
  }

  // Kill switch
  static Future<void> saveKillSwitch(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyKillSwitch, enabled);
  }

  static Future<bool> loadKillSwitch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyKillSwitch) ?? false;
  }

  // Clear all
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
