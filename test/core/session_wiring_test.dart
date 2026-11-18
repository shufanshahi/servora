import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/app.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/providers.dart';
import 'package:servora/core/router/app_router.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';
import 'package:servora/core/session/token_store.dart';

import '../support/app_harness.dart';
import '../support/fake_http_adapter.dart';
import '../support/fake_token_store.dart';
import '../support/fixtures.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ServoraApp)));

String currentPath(WidgetTester tester) =>
    containerOf(tester)
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;

void main() {
  group('router follows the real session', () {
    testWidgets('signed out: redirected to the login screen', (tester) async {
      final store = FakeTokenStore();
      await tester.pumpWidget(servoraAppWithRealSession(store));
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/login');
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('while the saved session is being read: splash screen', (
      tester,
    ) async {
      await tester.pumpWidget(servoraApp(status: AuthStatus.unknown));
      await tester.pump();
      expect(currentPath(tester), '/splash');
    });

    testWidgets('a saved valid session goes straight to Home on launch', (
      tester,
    ) async {
      final store = FakeTokenStore(storedSession());
      await tester.pumpWidget(servoraAppWithRealSession(store));
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/home');
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a saved expired session is cleared and shows login', (
      tester,
    ) async {
      final store = FakeTokenStore(
        storedSession(expiresAt: DateTime.utc(2000)),
      );
      await tester.pumpWidget(servoraAppWithRealSession(store));
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/login');
      expect(store.session, isNull);
      final state = containerOf(tester).read(sessionProvider);
      expect((state as SessionUnauthenticated).message, sessionExpiredMessage);
    });

    testWidgets('signing in moves from login to Home', (tester) async {
      final store = FakeTokenStore();
      await tester.pumpWidget(servoraAppWithRealSession(store));
      await tester.pumpAndSettle();
      expect(currentPath(tester), '/login');

      await containerOf(tester)
          .read(sessionProvider.notifier)
          .signIn(authResult().toStoredSession());
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/home');
      expect(store.session!.accessToken, 'jwt-token');
    });
  });

  group('logout', () {
    testWidgets('returns to login, clears storage, and back cannot return', (
      tester,
    ) async {
      final store = FakeTokenStore(storedSession());
      await tester.pumpWidget(servoraAppWithRealSession(store));
      await tester.pumpAndSettle();
      expect(currentPath(tester), '/home');

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      final signOut = find.widgetWithText(OutlinedButton, 'Sign out');
      await tester.scrollUntilVisible(
        signOut,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(signOut);
      await tester.pumpAndSettle();
      // The app asks first.
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/login');
      expect(store.session, isNull);
      expect(find.byType(NavigationBar), findsNothing);

      // The authenticated screens are gone from the navigation stack entirely.
      final router = containerOf(tester).read(routerProvider);
      expect(router.canPop(), isFalse);

      // Even asking for a protected page directly bounces back to login.
      router.go('/bookings');
      await tester.pumpAndSettle();
      expect(currentPath(tester), '/login');
    });
  });

  group('API client uses the session', () {
    test('sends the signed-in token and nothing once signed out', () async {
      final adapter = FakeHttpAdapter()
        ..reply(200, {'success': true, 'data': null})
        ..reply(200, {'success': true, 'data': null});
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(FakeTokenStore()),
          httpClientAdapterProvider.overrideWithValue(adapter),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      await notifier.restore();

      await notifier.signIn(authResult().toStoredSession());
      await container.read(apiClientProvider).get('/anything');
      expect(adapter.lastRequest.headers['Authorization'], 'Bearer jwt-token');

      await notifier.logout();
      await container.read(apiClientProvider).get('/anything');
      expect(adapter.lastRequest.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('token rejected mid-session (401)', () {
    testWidgets('ends the session, returns to login, and says why', (
      tester,
    ) async {
      final store = FakeTokenStore(storedSession());
      final adapter = FakeHttpAdapter()
        ..reply(401, {
          'success': false,
          'error': {
            'code': 'UNAUTHENTICATED',
            'message': 'Authentication required',
          },
        });
      await tester.pumpWidget(
        servoraAppWithRealSession(
          store,
          overrides: [httpClientAdapterProvider.overrideWithValue(adapter)],
        ),
      );
      await tester.pumpAndSettle();
      expect(currentPath(tester), '/home');

      // Any API call the user triggers comes back 401.
      final container = containerOf(tester);
      // Real network-style calls need real async time, not the test's fake clock.
      final failure = await tester.runAsync(() async {
        try {
          await container.read(apiClientProvider).get('/users/me');
        } on AppFailure catch (error) {
          return error;
        }
        return null;
      });
      await tester.pumpAndSettle();

      expect(failure, isA<UnauthenticatedFailure>());
      expect(adapter.lastRequest.headers['Authorization'], 'Bearer jwt-token');
      expect(currentPath(tester), '/login');
      expect(store.session, isNull);
      final state = container.read(sessionProvider) as SessionUnauthenticated;
      expect(state.message, sessionExpiredMessage);
      expect(container.read(routerProvider).canPop(), isFalse);
    });

    testWidgets('a failed login does NOT sign anyone out', (tester) async {
      final store = FakeTokenStore(storedSession());
      final adapter = FakeHttpAdapter()
        ..reply(401, {
          'success': false,
          'error': {
            'code': 'INVALID_CREDENTIALS',
            'message': 'Incorrect email or password',
          },
        });
      await tester.pumpWidget(
        servoraAppWithRealSession(
          store,
          overrides: [httpClientAdapterProvider.overrideWithValue(adapter)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        try {
          await containerOf(tester)
              .read(apiClientProvider)
              .post('/auth/login', authenticated: false);
        } on AppFailure {
          // expected
        }
      });
      await tester.pumpAndSettle();

      expect(currentPath(tester), '/home');
      expect(store.session, isNotNull);
    });
  });
}
