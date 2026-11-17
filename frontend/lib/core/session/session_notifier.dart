import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/session/session_state.dart';
import 'package:servora/core/session/stored_session.dart';
import 'package:servora/core/session/token_store.dart';

/// Source of "now", replaceable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

const sessionExpiredMessage = 'Your session has expired. Please sign in again.';

/// Owns the signed-in state and keeps the saved session in step with it.
class SessionNotifier extends Notifier<SessionState> {
  Future<void>? _restore;

  TokenStore get _store => ref.read(tokenStoreProvider);

  @override
  SessionState build() {
    // Read the saved session as soon as the app starts. Until it finishes the
    // state is "unknown" and the router shows a splash screen.
    scheduleMicrotask(() => unawaited(restore()));
    return const SessionUnknown();
  }

  /// Reads the saved session once. Safe to call more than once.
  Future<void> restore() => _restore ??= _doRestore();

  Future<void> _doRestore() async {
    StoredSession? saved;
    try {
      saved = await _store.read();
    } on Object {
      // A broken keystore must never trap the user: start signed out.
      saved = null;
    }
    if (!ref.mounted) return;

    if (saved == null) {
      state = const SessionUnauthenticated();
      return;
    }
    if (saved.isExpiredAt(ref.read(clockProvider)())) {
      await _clearStore();
      if (!ref.mounted) return;
      state = const SessionUnauthenticated(message: sessionExpiredMessage);
      return;
    }
    state = SessionAuthenticated(
      user: saved.user,
      accessToken: saved.accessToken,
      expiresAt: saved.expiresAt,
    );
  }

  /// Signs the user in after a successful register or login and saves the session.
  Future<void> signIn(StoredSession session) async {
    try {
      await _store.write(session);
    } on Object {
      // If the keystore refuses the write the user is still signed in for this
      // run; they just will not stay signed in after a restart.
    }
    if (!ref.mounted) return;
    state = SessionAuthenticated(
      user: session.user,
      accessToken: session.accessToken,
      expiresAt: session.expiresAt,
    );
  }

  /// The user chose to sign out: remove the token and cached user.
  Future<void> logout() async {
    // Flip the state first so the UI leaves protected screens immediately.
    state = const SessionUnauthenticated();
    await _clearStore();
  }

  /// The server rejected our token. Ignored unless someone is signed in, so a late
  /// response after logout cannot show a stray message.
  Future<void> expire() async {
    if (state is! SessionAuthenticated) return;
    state = const SessionUnauthenticated(message: sessionExpiredMessage);
    await _clearStore();
  }

  Future<void> _clearStore() async {
    try {
      await _store.clear();
    } on Object {
      // Nothing more can be done; the in-memory state is already signed out.
    }
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
