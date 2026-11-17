import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a user is signed in. The router reads this to decide where to send people.
enum AuthStatus {
  /// Still restoring a saved session (shows a splash screen).
  unknown,
  authenticated,
  unauthenticated,
}

/// Placeholder auth state so navigation can be built and tested before the auth
/// feature exists. `add-user-auth` replaces this provider with the real session.
class AuthStatusNotifier extends Notifier<AuthStatus> {
  @override
  AuthStatus build() => AuthStatus.unauthenticated;

  // ignore: use_setters_to_change_properties
  void set(AuthStatus status) => state = status;
}

final authStatusProvider = NotifierProvider<AuthStatusNotifier, AuthStatus>(
  AuthStatusNotifier.new,
);
