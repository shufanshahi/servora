import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/app.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';
import 'package:servora/core/session/token_store.dart';

import 'fake_token_store.dart';
import 'fixtures.dart';

/// A session that is exactly [initial] and never restores from storage, so a test
/// can start in any state without waiting.
class _FixedSession extends SessionNotifier {
  _FixedSession(this.initial);

  final SessionState initial;

  @override
  SessionState build() => initial;
}

SessionState sessionFor(AuthStatus status) => switch (status) {
  AuthStatus.unknown => const SessionUnknown(),
  AuthStatus.unauthenticated => const SessionUnauthenticated(),
  AuthStatus.authenticated => SessionAuthenticated(
    user: testUser,
    accessToken: 'jwt-token',
    expiresAt: DateTime.utc(2099),
  ),
};

/// The whole app starting in a chosen auth state, with the session held in memory.
Widget servoraApp({
  AuthStatus status = AuthStatus.unauthenticated,
  SessionState? session,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith(
        () => _FixedSession(session ?? sessionFor(status)),
      ),
      ...overrides,
    ],
    child: const ServoraApp(),
  );
}

/// The whole app with the REAL session notifier on top of [store], for tests that
/// sign in and out. Starts in "unknown" and restores from [store] like a real launch.
Widget servoraAppWithRealSession(
  FakeTokenStore store, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [tokenStoreProvider.overrideWithValue(store), ...overrides],
    child: const ServoraApp(),
  );
}

/// Sets a logical screen size (dp) for the test and restores it afterwards.
void useScreen(
  WidgetTester tester, {
  required double width,
  required double height,
  double textScale = 1.0,
}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
