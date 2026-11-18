import 'package:servora/core/domain/app_user.dart';

/// What is kept on the device between launches: the access token, when it
/// expires, and the user it belongs to (so the app can start without a network call).
class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.expiresAt,
    required this.user,
  });

  factory StoredSession.fromJson(Map<String, dynamic> json) {
    return StoredSession(
      accessToken: json['accessToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final DateTime expiresAt;
  final AppUser user;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'user': user.toJson(),
  };
}
