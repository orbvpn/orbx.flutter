import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final UserSubscription? subscription;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.subscription,
    this.createdAt,
    this.updatedAt,
  });

  /// Full name getter
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return firstName ?? lastName ?? email;
  }

  /// Display name (for UI)
  String get displayName {
    return fullName;
  }

  /// Check if subscription is active
  bool get hasActiveSubscription {
    if (subscription == null) return false;
    if (subscription!.expiryDate == null) return true; // lifetime subscription
    return subscription!.expiryDate!.isAfter(DateTime.now());
  }

  /// Factory constructor from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    // ✅ FIX: Backend has nested profile structure
    final profile = json['profile'] as Map<String, dynamic>?;

    return User(
      id: json['id'].toString(), // ✅ Convert int to string (backend sends Int)
      email: json['email'] as String,

      // ✅ FIX: firstName/lastName are nested in profile object
      firstName: profile?['firstName'] as String?,
      lastName: profile?['lastName'] as String?,

      subscription: json['subscription'] != null
          ? UserSubscription.fromJson(
              json['subscription'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'profile': {
        'firstName': firstName,
        'lastName': lastName,
      },
      'subscription': subscription?.toJson(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  User copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    UserSubscription? subscription,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      subscription: subscription ?? this.subscription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        firstName,
        lastName,
        subscription,
        createdAt,
        updatedAt,
      ];

  @override
  bool get stringify => true;
}

/// User Subscription Model
class UserSubscription extends Equatable {
  final String id;
  final String planName;
  final int maxDevices;
  final DateTime? expiryDate;
  final bool isActive;

  const UserSubscription({
    required this.id,
    required this.planName,
    required this.maxDevices,
    this.expiryDate,
    this.isActive = true,
  });

  /// Check if subscription is expired
  bool get isExpired {
    if (expiryDate == null) return false; // lifetime
    return expiryDate!.isBefore(DateTime.now());
  }

  /// Days remaining until expiry
  int? get daysRemaining {
    if (expiryDate == null) return null; // lifetime
    final difference = expiryDate!.difference(DateTime.now());
    return difference.inDays;
  }

  /// Factory constructor from JSON
  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    // ✅ FIX: Backend has nested group structure
    final group = json['group'] as Map<String, dynamic>?;

    return UserSubscription(
      // ✅ id comes from group.id
      id: group?['id']?.toString() ?? '0',
      // ✅ planName comes from group.name
      planName: group?['name'] as String? ?? 'Unknown Plan',
      // ✅ maxDevices is called multiLoginCount in backend
      maxDevices: json['multiLoginCount'] as int? ?? 1,

      expiryDate: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,

      // Calculate if active based on expiry date
      isActive: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String).isAfter(DateTime.now())
          : true,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'group': {
        'id': int.tryParse(id) ?? 0,
        'name': planName,
      },
      'multiLoginCount': maxDevices,
      'expiresAt': expiryDate?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  UserSubscription copyWith({
    String? id,
    String? planName,
    int? maxDevices,
    DateTime? expiryDate,
    bool? isActive,
  }) {
    return UserSubscription(
      id: id ?? this.id,
      planName: planName ?? this.planName,
      maxDevices: maxDevices ?? this.maxDevices,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, planName, maxDevices, expiryDate, isActive];

  @override
  bool get stringify => true;
}
