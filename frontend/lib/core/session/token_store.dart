import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:servora/core/session/stored_session.dart';

/// Persists the session between app launches.
abstract interface class TokenStore {
  /// The saved session, or null if there is none (or it was unreadable).
  Future<StoredSession?> read();

  Future<void> write(StoredSession session);

  /// Removes the token and the cached user.
  Future<void> clear();
}

/// Keeps the session in platform-secure storage (Android Keystore-backed), never in
/// plain shared preferences.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'servora.session';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return StoredSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // Corrupted or from an incompatible version: treat as signed out and
      // remove it so it cannot cause the same problem on the next launch.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
