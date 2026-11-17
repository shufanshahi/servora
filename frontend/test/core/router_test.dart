import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/router/app_router.dart';
import 'package:servora/core/router/auth_status.dart';
import 'package:servora/core/router/routes.dart';

import '../support/app_harness.dart';

void main() {
  group('redirectFor', () {
    test('unauthenticated users are sent to login from protected routes', () {
      for (final route in [
        AppRoutes.home,
        AppRoutes.bookings,
        AppRoutes.assistant,
        AppRoutes.profile,
        '/services/42',
      ]) {
        expect(
          redirectFor(AuthStatus.unauthenticated, route),
          AppRoutes.login,
          reason: route,
        );
      }
    });

    test('unauthenticated users may stay on login and register', () {
      expect(redirectFor(AuthStatus.unauthenticated, AppRoutes.login), isNull);
      expect(
        redirectFor(AuthStatus.unauthenticated, AppRoutes.register),
        isNull,
      );
    });

    test('authenticated users are kept off the auth screens', () {
      expect(
        redirectFor(AuthStatus.authenticated, AppRoutes.login),
        AppRoutes.home,
      );
      expect(
        redirectFor(AuthStatus.authenticated, AppRoutes.splash),
        AppRoutes.home,
      );
      expect(redirectFor(AuthStatus.authenticated, AppRoutes.bookings), isNull);
    });

    test('while the session is restoring everyone waits on the splash', () {
      expect(redirectFor(AuthStatus.unknown, AppRoutes.home), AppRoutes.splash);
      expect(redirectFor(AuthStatus.unknown, AppRoutes.splash), isNull);
    });
  });

  group('navigation', () {
    testWidgets('an unauthenticated start lands on the login screen', (
      tester,
    ) async {
      await tester.pumpWidget(servoraApp());
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('an authenticated start goes straight to Home', (tester) async {
      await tester.pumpWidget(servoraApp(status: AuthStatus.authenticated));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Placeholder service 1'), findsOneWidget);
    });

    testWidgets('the session-restoring state shows the splash', (tester) async {
      await tester.pumpWidget(servoraApp(status: AuthStatus.unknown));
      await tester.pump();
      expect(find.text('Starting Servora'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('each tab shows its own screen', (tester) async {
      await tester.pumpWidget(servoraApp(status: AuthStatus.authenticated));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Bookings'));
      await tester.pumpAndSettle();
      expect(find.text('No bookings yet'), findsOneWidget);

      await tester.tap(find.text('Assistant'));
      await tester.pumpAndSettle();
      expect(find.textContaining('recommendations'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Your details will appear here.'), findsOneWidget);
    });

    testWidgets('tabs preserve their scroll position when switching', (
      tester,
    ) async {
      useScreen(tester, width: 400, height: 800);
      await tester.pumpWidget(servoraApp(status: AuthStatus.authenticated));
      await tester.pumpAndSettle();

      double homeOffset() => tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;

      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      final scrolledTo = homeOffset();
      expect(scrolledTo, greaterThan(500));

      await tester.tap(find.text('My Bookings'));
      await tester.pumpAndSettle();
      expect(find.text('No bookings yet'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(homeOffset(), scrolledTo);
    });

    testWidgets('tapping the active tab returns it to its first screen', (
      tester,
    ) async {
      await tester.pumpWidget(servoraApp(status: AuthStatus.authenticated));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Placeholder service 1'), findsOneWidget);
    });
  });
}
