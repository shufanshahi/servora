import 'dart:convert';

/// Client-side form rules. They mirror the API's validation exactly (same limits, same
/// messages), so a form rejects what the server would reject and shows the same words.
/// Each method returns an error message, or null when the value is acceptable.
abstract final class AuthValidators {
  static const nameMaxLength = 100;
  static const emailMaxLength = 254;
  static const passwordMinLength = 8;

  /// bcrypt only uses the first 72 bytes, so the API rejects anything longer.
  static const passwordMaxBytes = 72;

  // Same pattern the API's email check uses: no leading or doubled dots, a dotted
  // domain, and a TLD of at least two letters.
  static final RegExp _email = RegExp(
    r"^(?!\.)(?!.*\.\.)([A-Za-z0-9_'+\-.]*)[A-Za-z0-9_+-]@([A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$",
  );

  static String? name(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Name is required';
    if (text.length > nameMaxLength) {
      return 'Name must be at most $nameMaxLength characters';
    }
    return null;
  }

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Email is required';
    if (text.length > emailMaxLength) return 'Email is too long';
    if (!_email.hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  /// Rules for choosing a password (registration).
  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < passwordMinLength) {
      return 'Password must be at least $passwordMinLength characters';
    }
    if (!RegExp('[A-Za-z]').hasMatch(text)) {
      return 'Password must contain a letter';
    }
    if (!RegExp(r'\d').hasMatch(text)) return 'Password must contain a number';
    if (utf8.encode(text).length > passwordMaxBytes) {
      return 'Password must be at most $passwordMaxBytes bytes';
    }
    return null;
  }

  /// Login only checks that something was typed. It does not repeat the strength
  /// rules, so the screen never hints at what a valid password looks like.
  static String? existingPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Password is required';
    return null;
  }
}
