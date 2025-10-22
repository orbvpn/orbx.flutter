/// Input Validators
///
/// Provides validation functions for form inputs throughout the app.

import '../../core/constants/api_constants.dart';

class Validators {
  Validators._(); // Private constructor

  /// Validate email address
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(ApiConstants.emailPattern);
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < ApiConstants.minPasswordLength) {
      return 'Password must be at least ${ApiConstants.minPasswordLength} characters';
    }

    if (value.length > ApiConstants.maxPasswordLength) {
      return 'Password must be less than ${ApiConstants.maxPasswordLength} characters';
    }

    // Check for at least one letter and one number
    if (!value.contains(RegExp(r'[A-Za-z]'))) {
      return 'Password must contain at least one letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  /// Validate confirm password (must match original)
  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Validate required field
  static String? validateRequired(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? "This field"} is required';
    }
    return null;
  }

  /// Validate name (first name, last name)
  static String? validateName(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? "Name"} is required';
    }

    if (value.length < 2) {
      return '${fieldName ?? "Name"} must be at least 2 characters';
    }

    if (value.length > 50) {
      return '${fieldName ?? "Name"} must be less than 50 characters';
    }

    // Only allow letters, spaces, hyphens, and apostrophes
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value)) {
      return '${fieldName ?? "Name"} can only contain letters, spaces, hyphens, and apostrophes';
    }

    return null;
  }

  /// Validate phone number
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove common formatting characters
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  /// Validate referral code (optional field)
  static String? validateReferralCode(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    if (value.length < 4 || value.length > 20) {
      return 'Referral code must be between 4-20 characters';
    }

    // Only allow alphanumeric characters
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
      return 'Referral code can only contain letters and numbers';
    }

    return null;
  }

  /// Validate URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'URL is required';
    }

    final urlPattern = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
      caseSensitive: false,
    );

    if (!urlPattern.hasMatch(value)) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  /// Validate numeric input
  static String? validateNumeric(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? "This field"} is required';
    }

    if (double.tryParse(value) == null) {
      return '${fieldName ?? "This field"} must be a number';
    }

    return null;
  }

  /// Validate integer input
  static String? validateInteger(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? "This field"} is required';
    }

    if (int.tryParse(value) == null) {
      return '${fieldName ?? "This field"} must be a whole number';
    }

    return null;
  }

  /// Validate range (for numeric values)
  static String? validateRange(
    String? value, {
    required double min,
    required double max,
    String? fieldName,
  }) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? "This field"} is required';
    }

    final number = double.tryParse(value);
    if (number == null) {
      return '${fieldName ?? "This field"} must be a number';
    }

    if (number < min || number > max) {
      return '${fieldName ?? "This field"} must be between $min and $max';
    }

    return null;
  }

  /// Validate minimum length
  static String? validateMinLength(
    String? value,
    int minLength, {
    String? fieldName,
  }) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? "This field"} is required';
    }

    if (value.length < minLength) {
      return '${fieldName ?? "This field"} must be at least $minLength characters';
    }

    return null;
  }

  /// Validate maximum length
  static String? validateMaxLength(
    String? value,
    int maxLength, {
    String? fieldName,
  }) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? "This field"} is required';
    }

    if (value.length > maxLength) {
      return '${fieldName ?? "This field"} must be less than $maxLength characters';
    }

    return null;
  }
}
