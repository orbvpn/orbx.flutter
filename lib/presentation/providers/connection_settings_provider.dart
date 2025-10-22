import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/vpn_protocols.dart';
import '../../core/constants/mimicry_protocols.dart';
import '../../core/constants/mimicry_mode.dart';
import '../../core/utils/preferences_helper.dart';
import '../../core/services/mimicry_manager.dart';
import '../../data/models/server.dart';

class ConnectionSettingsProvider extends ChangeNotifier {
  final MimicryManager _mimicryManager;

  ConnectionSettingsProvider(this._mimicryManager);

  // VPN Protocol
  VPNProtocol _vpnProtocol = VPNProtocol.wireguard;

  // Mimicry Settings
  MimicryMode _mimicryMode = MimicryMode.auto;
  MimicryProtocol _selectedMimicry = MimicryProtocol.teams;
  MimicryProtocol? _autoDetectedMimicry;

  bool _isLoading = false;
  String? _userCountryCode;

  // Getters
  VPNProtocol get vpnProtocol => _vpnProtocol;
  MimicryMode get mimicryMode => _mimicryMode;
  MimicryProtocol get selectedMimicry => _selectedMimicry;
  MimicryProtocol? get autoDetectedMimicry => _autoDetectedMimicry;
  bool get isLoading => _isLoading;
  String? get userCountryCode => _userCountryCode;

  // Get effective mimicry (Auto or Manual)
  MimicryProtocol get effectiveMimicry {
    if (_mimicryMode == MimicryMode.auto && _autoDetectedMimicry != null) {
      return _autoDetectedMimicry!;
    }
    return _selectedMimicry;
  }

  // Initialize
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load saved settings
      _vpnProtocol = await PreferencesHelper.loadVpnProtocol();
      _mimicryMode = await PreferencesHelper.loadMimicryMode();
      _selectedMimicry = await PreferencesHelper.loadSelectedMimicry();

      // Detect user location
      await _detectUserLocation();
    } catch (e) {
      debugPrint('Error initializing settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Change VPN Protocol
  Future<void> setVpnProtocol(VPNProtocol protocol) async {
    if (!protocol.isAvailable) {
      debugPrint('Protocol ${protocol.name} is not available yet');
      return;
    }

    _vpnProtocol = protocol;
    notifyListeners();

    try {
      await PreferencesHelper.saveVpnProtocol(protocol);
    } catch (e) {
      debugPrint('Error saving VPN protocol: $e');
    }
  }

  // Change Mimicry Mode (Auto/Manual)
  Future<void> setMimicryMode(MimicryMode mode) async {
    _mimicryMode = mode;
    notifyListeners();

    try {
      await PreferencesHelper.saveMimicryMode(mode);

      // If switching to Auto, detect best mimicry
      if (mode == MimicryMode.auto) {
        await autoDetectBestMimicry(null);
      }
    } catch (e) {
      debugPrint('Error saving mimicry mode: $e');
    }
  }

  // Set Manual Mimicry
  Future<void> setManualMimicry(MimicryProtocol protocol) async {
    _selectedMimicry = protocol;
    _mimicryMode = MimicryMode.manual;
    notifyListeners();

    try {
      await PreferencesHelper.saveSelectedMimicry(protocol);
      await PreferencesHelper.saveMimicryMode(MimicryMode.manual);
    } catch (e) {
      debugPrint('Error saving manual mimicry: $e');
    }
  }

  // Auto-detect best mimicry based on location and testing
  Future<void> autoDetectBestMimicry(OrbXServer? server) async {
    if (_mimicryMode != MimicryMode.auto) return;

    try {
      if (server != null) {
        // Test all protocols and pick best one
        _autoDetectedMimicry = await _mimicryManager.getBestProtocol(
          server,
          _userCountryCode,
        );
      } else {
        // Without server, use location-based heuristics
        _autoDetectedMimicry = _guessBlindlyBestMimicryByLocation();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error auto-detecting mimicry: $e');
      _autoDetectedMimicry = MimicryProtocol.teams; // Fallback
      notifyListeners();
    }
  }

  // Detect user's country
  Future<void> _detectUserLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied');
        _userCountryCode = null;
        return;
      }

      // Get position (or use IP-based geolocation as fallback)
      // For now, we'll use a placeholder
      // TODO: Integrate with IP geolocation API
      _userCountryCode = 'IR'; // Placeholder
    } catch (e) {
      debugPrint('Error detecting location: $e');
      _userCountryCode = null;
    }
  }

  // Heuristic: Guess best mimicry without server testing
  MimicryProtocol _guessBlindlyBestMimicryByLocation() {
    if (_userCountryCode == null) {
      return MimicryProtocol.teams; // Universal default
    }

    // Iran
    if (_userCountryCode == 'IR') {
      return MimicryProtocol.shaparak; // Iranian banking is best for Iran
    }

    // Russia
    if (_userCountryCode == 'RU') {
      return MimicryProtocol.yandex;
    }

    // China
    if (_userCountryCode == 'CN') {
      return MimicryProtocol.wechat;
    }

    // Default: Teams (most universal)
    return MimicryProtocol.teams;
  }

  // Get summary string
  String getSummaryString() {
    final vpnName = _vpnProtocol.name;
    final mimicryName = effectiveMimicry.name;
    final modeStr = _mimicryMode == MimicryMode.auto ? '(Auto)' : '(Manual)';

    return '$vpnName + $mimicryName $modeStr';
  }
}
