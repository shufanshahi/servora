import 'package:servora/core/domain/app_user.dart';
import 'package:servora/core/session/stored_session.dart';

/// Successful register or login: the user and their access token.
class AuthResult {
  const AuthResult({
    required this.user,
    required this.accessToken,
    required this.expiresAt,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  final AppUser user;
  final String accessToken;
  final DateTime expiresAt;

  StoredSession toStoredSession() =>
      StoredSession(accessToken: accessToken, expiresAt: expiresAt, user: user);
}
