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

  // ✅ ADD THESE TWO FIELDS
  final String? protocol; // Mimicry protocol (http, teams, shaparak, etc.)
  final String? authToken; // Authentication token for HTTP tunnel

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
    // ✅ ADD THESE TWO PARAMETERS
    this.protocol, // Optional, defaults to null
    this.authToken, // Optional, defaults to null
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
      // ✅ ADD THESE TWO FIELDS
      'protocol': protocol,
      'authToken': authToken,
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
      // ✅ ADD THESE TWO FIELDS
      protocol: json['protocol'] as String?,
      authToken: json['authToken'] as String?,
    );
  }

  // ✅ ADD copyWith method for easy modification
  WireGuardConfig copyWith({
    String? privateKey,
    String? publicKey,
    String? serverPublicKey,
    String? allocatedIp,
    String? gateway,
    List<String>? dns,
    int? mtu,
    String? serverEndpoint,
    int? persistentKeepalive,
    String? protocol,
    String? authToken,
  }) {
    return WireGuardConfig(
      privateKey: privateKey ?? this.privateKey,
      publicKey: publicKey ?? this.publicKey,
      serverPublicKey: serverPublicKey ?? this.serverPublicKey,
      allocatedIp: allocatedIp ?? this.allocatedIp,
      gateway: gateway ?? this.gateway,
      dns: dns ?? this.dns,
      mtu: mtu ?? this.mtu,
      serverEndpoint: serverEndpoint ?? this.serverEndpoint,
      persistentKeepalive: persistentKeepalive ?? this.persistentKeepalive,
      protocol: protocol ?? this.protocol,
      authToken: authToken ?? this.authToken,
    );
  }
}
