import 'package:servora/core/domain/app_user.dart';

/// Whether a user is signed in. The router reads this to decide where to send people.
enum AuthStatus {
  /// Still restoring a saved session (shows a splash screen).
  unknown,
  authenticated,
  unauthenticated,
}

/// The app's single source of truth about who is signed in.
sealed class SessionState {
  const SessionState();

  AuthStatus get status;
}

/// The saved session has not been read yet.
class SessionUnknown extends SessionState {
  const SessionUnknown();

  @override
  AuthStatus get status => AuthStatus.unknown;
}

class SessionAuthenticated extends SessionState {
  const SessionAuthenticated({
    required this.user,
    required this.accessToken,
    required this.expiresAt,
  });

  final AppUser user;
  final String accessToken;
  final DateTime expiresAt;

  @override
  AuthStatus get status => AuthStatus.authenticated;
}

class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.message});

  /// Why the user was signed out, when it was not their choice (for example
  /// "Your session has expired"). The login screen shows it once.
  final String? message;

  @override
  AuthStatus get status => AuthStatus.unauthenticated;
}
