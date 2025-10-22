/// Authentication Response Model
///
/// Represents the response from login/register operations containing
/// access tokens and user information.
library;

import 'package:equatable/equatable.dart';
import 'user.dart';

class AuthResponse extends Equatable {
  final String accessToken;
  final String refreshToken;
  final User user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  /// Factory constructor from JSON (for login mutation)
  factory AuthResponse.fromLoginJson(Map<String, dynamic> json) {
    final loginData = json['login'] as Map<String, dynamic>;
    return AuthResponse(
      accessToken: loginData['accessToken'] as String,
      refreshToken: loginData['refreshToken'] as String,
      user: User.fromJson(loginData['user'] as Map<String, dynamic>),
    );
  }

  /// Factory constructor from JSON (for register mutation)
  factory AuthResponse.fromRegisterJson(Map<String, dynamic> json) {
    final registerData = json['register'] as Map<String, dynamic>;
    return AuthResponse(
      accessToken: registerData['accessToken'] as String,
      refreshToken: registerData['refreshToken'] as String,
      user: User.fromJson(registerData['user'] as Map<String, dynamic>),
    );
  }

  /// Generic factory from JSON
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }

  /// Create a copy with updated fields
  AuthResponse copyWith({
    String? accessToken,
    String? refreshToken,
    User? user,
  }) {
    return AuthResponse(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, user];

  @override
  bool get stringify => true;
}

/// Login Request Model
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

/// Register Request Model
class RegisterRequest {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String? referralCode;

  const RegisterRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    this.referralCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      if (referralCode != null) 'referralCode': referralCode,
    };
  }
}
