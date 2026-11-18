import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';
import 'package:servora/features/auth/data/auth_repository.dart';
import 'package:servora/features/auth/domain/auth_result.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_token_store.dart';
import '../../support/fixtures.dart';

late FakeAuthRepository repo;
late FakeTokenStore store;

Future<void> openLogin(WidgetTester tester) async {
  useScreen(tester, width: 400, height: 900);
  repo = FakeAuthRepository();
  store = FakeTokenStore();
  await tester.pumpWidget(
    servoraAppWithRealSession(
      store,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    ),
  );
  await tester.pumpAndSettle();
}

Finder field(int index) => find.byType(TextFormField).at(index);
Finder get emailField => field(0);
Finder get passwordField => field(1);
Finder get signInButton => find.widgetWithText(FilledButton, 'Sign in');

Future<void> fillAndSubmit(
  WidgetTester tester, {
  String email = 'ada@example.com',
  String password = 'Sup3rSecret',
}) async {
  await tester.enterText(emailField, email);
  await tester.enterText(passwordField, password);
  await tester.ensureVisible(signInButton);
  await tester.tap(signInButton);
  await tester.pump();
}

String editableText(WidgetTester tester, int index) => tester
    .widget<EditableText>(
      find.descendant(of: field(index), matching: find.byType(EditableText)),
    )
    .controller
    .text;

void main() {
  testWidgets('shows the form with email, password and both actions', (
    tester,
  ) async {
    await openLogin(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(signInButton, findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  group('inline validation', () {
    testWidgets('empty submit shows what is missing and sends nothing', (
      tester,
    ) async {
      await openLogin(tester);
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton);
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(repo.loginCalls, isEmpty);
    });

    testWidgets('a malformed email is flagged as the user types', (
      tester,
    ) async {
      await openLogin(tester);
      await tester.enterText(emailField, 'not-an-email');
      await tester.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('login does not lecture about password strength', (
      tester,
    ) async {
      await openLogin(tester);
      repo.onLogin = (_, _) async => throw const UnauthenticatedFailure(
        code: 'INVALID_CREDENTIALS',
        message: 'Incorrect email or password',
      );
      await fillAndSubmit(tester, password: 'a');
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 8'), findsNothing);
      expect(repo.loginCalls, hasLength(1));
    });
  });

  group('submitting', () {
    testWidgets('success signs in, persists the session and opens Home', (
      tester,
    ) async {
      await openLogin(tester);
      repo.onLogin = (_, _) async => authResult();

      await fillAndSubmit(tester, email: '  ada@example.com ');
      await tester.pumpAndSettle();

      expect(repo.loginCalls.single.email, 'ada@example.com');
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(store.session!.accessToken, 'jwt-token');
    });

    testWidgets('while in flight the button is disabled with a spinner', (
      tester,
    ) async {
      await openLogin(tester);
      final pending = Completer<AuthResult>();
      repo.onLogin = (_, _) => pending.future;

      await fillAndSubmit(tester);

      final button = tester.widget<FilledButton>(
        find.byType(FilledButton).first,
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Sign in'),
        findsNothing,
      ); // label replaced by the spinner

      pending.complete(authResult());
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('repeated taps while in flight send exactly one request', (
      tester,
    ) async {
      await openLogin(tester);
      final pending = Completer<AuthResult>();
      repo.onLogin = (_, _) => pending.future;

      await fillAndSubmit(tester);
      // The button is disabled, and the keyboard "done" action is ignored too.
      await tester.tap(find.byType(FilledButton).first, warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(repo.loginCalls, hasLength(1));
      pending.complete(authResult());
      await tester.pumpAndSettle();
    });
  });

  group('errors', () {
    testWidgets(
      'wrong credentials: message shown, input kept, no retry offered',
      (tester) async {
        await openLogin(tester);
        repo.onLogin = (_, _) async => throw const UnauthenticatedFailure(
          code: 'INVALID_CREDENTIALS',
          message: 'Incorrect email or password',
        );

        await fillAndSubmit(tester);
        await tester.pumpAndSettle();

        expect(find.text('Incorrect email or password'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
        expect(editableText(tester, 0), 'ada@example.com');
        expect(editableText(tester, 1), 'Sup3rSecret');
        expect(find.byType(NavigationBar), findsNothing);
        expect(store.session, isNull);
      },
    );

    testWidgets('offline: connectivity message with retry, input untouched', (
      tester,
    ) async {
      await openLogin(tester);
      repo.onLogin = (_, _) async => throw const NetworkFailure();

      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(editableText(tester, 0), 'ada@example.com');
      expect(editableText(tester, 1), 'Sup3rSecret');
    });

    testWidgets('Try again repeats the request with the same values', (
      tester,
    ) async {
      await openLogin(tester);
      var attempt = 0;
      repo.onLogin = (_, _) async {
        attempt++;
        if (attempt == 1) throw const NetworkFailure();
        return authResult();
      };

      await fillAndSubmit(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(repo.loginCalls, hasLength(2));
      expect(repo.loginCalls.last.email, 'ada@example.com');
      expect(repo.loginCalls.last.password, 'Sup3rSecret');
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a server error is readable and retryable', (tester) async {
      await openLogin(tester);
      repo.onLogin = (_, _) async => throw const ServerFailure();
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('rate limiting is explained', (tester) async {
      await openLogin(tester);
      repo.onLogin = (_, _) async => throw const RateLimitedFailure();
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('too often'), findsOneWidget);
    });

    testWidgets('no raw exception text ever reaches the screen', (
      tester,
    ) async {
      await openLogin(tester);
      repo.onLogin = (_, _) async => throw const UnknownFailure();
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('UnknownFailure'), findsNothing);
    });

    testWidgets('a field message from the server appears and clears on edit', (
      tester,
    ) async {
      await openLogin(tester);
      repo.onLogin = (_, _) async => throw const ValidationFailure(
        fieldErrors: {'email': 'Enter a valid email address'},
      );
      await fillAndSubmit(tester, email: 'ada@example.com');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);

      await tester.enterText(emailField, 'ada@example.co');
      await tester.pump();
      expect(find.text('Enter a valid email address'), findsNothing);
    });
  });

  group('session notice', () {
    testWidgets('explains why the user was signed out', (tester) async {
      useScreen(tester, width: 400, height: 900);
      await tester.pumpWidget(
        servoraApp(
          session: const SessionUnauthenticated(message: sessionExpiredMessage),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(sessionExpiredMessage), findsOneWidget);
    });

    testWidgets('no notice when the user simply is not signed in', (
      tester,
    ) async {
      await openLogin(tester);
      expect(find.text(sessionExpiredMessage), findsNothing);
    });
  });

  testWidgets('"Create an account" opens the registration screen', (
    tester,
  ) async {
    await openLogin(tester);
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(AppRoutes.register, '/register');
  });

  testWidgets('fits a 320 dp screen with 2x text and stays reachable', (
    tester,
  ) async {
    useScreen(tester, width: 320, height: 640, textScale: 2.0);
    repo = FakeAuthRepository();
    store = FakeTokenStore();
    await tester.pumpWidget(
      servoraAppWithRealSession(
        store,
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      signInButton,
      100,
      // The form's own scrollable is first; the text fields contain smaller ones.
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(signInButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
