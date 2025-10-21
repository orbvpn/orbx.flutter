class WireGuardConfig {
  final String privateKey;
  final String publicKey;
  final String serverPublicKey;
  final String allocatedIp;
  final String gateway;
  final List<String> dns;
  final int mtu;
  final String serverEndpoint; // IP:Port
  final int persistentKeepalive;

  const WireGuardConfig({
    required this.privateKey,
    required this.publicKey,
    required this.serverPublicKey,
    required this.allocatedIp,
    required this.gateway,
    required this.dns,
    required this.mtu,
    required this.serverEndpoint,
    this.persistentKeepalive = 25,
  });

  // Generate WireGuard configuration file format
  String toConfigFile() {
    return '''
[Interface]
PrivateKey = $privateKey
Address = $allocatedIp/32
DNS = ${dns.join(', ')}
MTU = $mtu

[Peer]
PublicKey = $serverPublicKey
Endpoint = $serverEndpoint
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = $persistentKeepalive
''';
  }

  Map<String, dynamic> toJson() {
    return {
      'privateKey': privateKey,
      'publicKey': publicKey,
      'serverPublicKey': serverPublicKey,
      'allocatedIp': allocatedIp,
      'gateway': gateway,
      'dns': dns,
      'mtu': mtu,
      'serverEndpoint': serverEndpoint,
      'persistentKeepalive': persistentKeepalive,
    };
  }

  factory WireGuardConfig.fromJson(Map<String, dynamic> json) {
    return WireGuardConfig(
      privateKey: json['privateKey'] as String,
      publicKey: json['publicKey'] as String,
      serverPublicKey: json['serverPublicKey'] as String,
      allocatedIp: json['allocatedIp'] as String,
      gateway: json['gateway'] as String,
      dns: List<String>.from(json['dns'] as List),
      mtu: json['mtu'] as int,
      serverEndpoint: json['serverEndpoint'] as String,
      persistentKeepalive: json['persistentKeepalive'] as int? ?? 25,
    );
  }
}
