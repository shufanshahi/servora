import 'package:servora/core/domain/app_user.dart';
import 'package:servora/core/session/stored_session.dart';
import 'package:servora/features/auth/domain/auth_result.dart';

final testUser = AppUser(
  id: '3f0c9f2e-6a7c-4b0e-9a55-1d2f6e8a1c11',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  createdAt: DateTime.utc(2026, 11, 17, 10),
);

StoredSession storedSession({
  DateTime? expiresAt,
  String token = 'jwt-token',
  AppUser? user,
}) => StoredSession(
  accessToken: token,
  expiresAt: expiresAt ?? DateTime.utc(2099),
  user: user ?? testUser,
);

/// The `data` payload of a successful register/login response.
Map<String, dynamic> authPayload({DateTime? expiresAt}) => {
  'user': testUser.toJson(),
  'accessToken': 'jwt-token',
  'expiresAt': (expiresAt ?? DateTime.utc(2099)).toIso8601String(),
};

AuthResult authResult() => AuthResult.fromJson(authPayload());
