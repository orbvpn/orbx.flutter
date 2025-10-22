import 'package:equatable/equatable.dart';
import '../../core/constants/mimicry_protocols.dart';

class OrbXServer extends Equatable {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final String location;
  final String country;
  final String countryCode;
  final List<MimicryProtocol> protocols;
  final bool quantumSafe;
  final int currentConnections;
  final int maxConnections;
  final int? latencyMs;
  final bool enabled;
  final bool online;

  const OrbXServer({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.location,
    required this.country,
    required this.countryCode,
    required this.protocols,
    required this.quantumSafe,
    required this.currentConnections,
    required this.maxConnections,
    this.latencyMs,
    required this.enabled,
    required this.online,
  });

  // Parse from GraphQL response
  factory OrbXServer.fromJson(Map<String, dynamic> json) {
    return OrbXServer(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int,
      location: json['location'] as String,
      country: json['country'] as String,
      countryCode: json['countryCode'] as String? ?? '',
      protocols: (json['protocols'] as List<dynamic>)
          .map((p) => _parseProtocol(p as String))
          .toList(),
      quantumSafe: json['quantumSafe'] as bool? ?? true,
      currentConnections: json['currentConnections'] as int? ?? 0,
      maxConnections: json['maxConnections'] as int? ?? 100,
      latencyMs: json['latencyMs'] as int?,
      enabled: json['enabled'] as bool? ?? true,
      online: json['online'] as bool? ?? true,
    );
  }

  static MimicryProtocol _parseProtocol(String protocol) {
    switch (protocol.toLowerCase()) {
      case 'teams':
        return MimicryProtocol.teams;
      case 'shaparak':
        return MimicryProtocol.shaparak;
      case 'doh':
        return MimicryProtocol.doh;
      case 'https':
        return MimicryProtocol.https;
      case 'google':
        return MimicryProtocol.google;
      case 'zoom':
        return MimicryProtocol.zoom;
      case 'facetime':
        return MimicryProtocol.facetime;
      case 'vk':
        return MimicryProtocol.vk;
      case 'yandex':
        return MimicryProtocol.yandex;
      case 'wechat':
        return MimicryProtocol.wechat;
      default:
        return MimicryProtocol.https;
    }
  }

  bool get isAvailable => enabled && online;

  bool get hasCapacity => currentConnections < maxConnections;

  double get loadPercentage =>
      (currentConnections / maxConnections * 100).clamp(0, 100);

  @override
  List<Object?> get props => [
        id,
        name,
        ipAddress,
        port,
        location,
        country,
        protocols,
        latencyMs,
      ];

  OrbXServer copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    String? location,
    String? country,
    String? countryCode,
    List<MimicryProtocol>? protocols,
    bool? quantumSafe,
    int? currentConnections,
    int? maxConnections,
    int? latencyMs,
    bool? enabled,
    bool? online,
  }) {
    return OrbXServer(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      location: location ?? this.location,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      protocols: protocols ?? this.protocols,
      quantumSafe: quantumSafe ?? this.quantumSafe,
      currentConnections: currentConnections ?? this.currentConnections,
      maxConnections: maxConnections ?? this.maxConnections,
      latencyMs: latencyMs ?? this.latencyMs,
      enabled: enabled ?? this.enabled,
      online: online ?? this.online,
    );
  }
}
