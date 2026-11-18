import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';

export 'package:servora/core/session/session_state.dart' show AuthStatus;

/// What the router needs to know about the session: signed in, signed out, or still
/// restoring. Derived from the real session, so the router and the rest of the app
/// can never disagree.
final authStatusProvider = Provider<AuthStatus>(
  (ref) => ref.watch(sessionProvider).status,
);
