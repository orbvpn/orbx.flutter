enum VPNProtocol {
  wireguard,
  vless,
  cisco,
  orbx,
}

extension VPNProtocolExtension on VPNProtocol {
  String get name {
    switch (this) {
      case VPNProtocol.wireguard:
        return 'WireGuard';
      case VPNProtocol.vless:
        return 'VLESS';
      case VPNProtocol.cisco:
        return 'Cisco OpenConnect';
      case VPNProtocol.orbx:
        return 'OrbX Native';
    }
  }

  String get description {
    switch (this) {
      case VPNProtocol.wireguard:
        return 'Fast, modern VPN protocol (Currently Active)';
      case VPNProtocol.vless:
        return 'Lightweight proxy protocol (Coming Soon)';
      case VPNProtocol.cisco:
        return 'Enterprise-grade VPN (Coming Soon)';
      case VPNProtocol.orbx:
        return 'OrbX proprietary protocol (Coming Soon)';
    }
  }

  bool get isAvailable {
    switch (this) {
      case VPNProtocol.wireguard:
        return true; // ✅ Currently available
      case VPNProtocol.vless:
      case VPNProtocol.cisco:
      case VPNProtocol.orbx:
        return false; // 🔜 Coming soon
    }
  }

  String get apiValue {
    switch (this) {
      case VPNProtocol.wireguard:
        return 'WIREGUARD';
      case VPNProtocol.vless:
        return 'VLESS';
      case VPNProtocol.cisco:
        return 'OPENCONNECT';
      case VPNProtocol.orbx:
        return 'ORBX';
    }
  }
}
