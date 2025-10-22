class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final Subscription? subscription;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.subscription,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      subscription: json['subscription'] != null
          ? Subscription.fromJson(json['subscription'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'subscription': subscription?.toJson(),
    };
  }
}

class Subscription {
  final String id;
  final String planName;
  final int maxDevices;
  final String? expiryDate;

  Subscription({
    required this.id,
    required this.planName,
    required this.maxDevices,
    this.expiryDate,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      planName: json['planName'] as String,
      maxDevices: json['maxDevices'] as int,
      expiryDate: json['expiryDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planName': planName,
      'maxDevices': maxDevices,
      'expiryDate': expiryDate,
    };
  }
}

// AuthResponse class for login/register responses
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }
}
