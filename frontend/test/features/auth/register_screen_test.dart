import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/widgets/message_banner.dart';
import 'package:servora/features/auth/data/auth_repository.dart';
import 'package:servora/features/auth/domain/auth_result.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_token_store.dart';
import '../../support/fixtures.dart';

late FakeAuthRepository repo;
late FakeTokenStore store;

Future<void> openRegister(WidgetTester tester, {double textScale = 1}) async {
  useScreen(tester, width: 400, height: 1000, textScale: textScale);
  repo = FakeAuthRepository();
  store = FakeTokenStore();
  await tester.pumpWidget(
    servoraAppWithRealSession(
      store,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    ),
  );
  await tester.pumpAndSettle();
  // From the sign-in screen to the registration screen, like a real user.
  await tester.tap(find.text('Create an account'));
  await tester.pumpAndSettle();
}

Finder field(int index) => find.byType(TextFormField).at(index);
Finder get nameField => field(0);
Finder get emailField => field(1);
Finder get passwordField => field(2);
Finder get createButton => find.widgetWithText(FilledButton, 'Create account');

Future<void> fill(
  WidgetTester tester, {
  String name = 'Ada Lovelace',
  String email = 'ada@example.com',
  String password = 'Sup3rSecret',
}) async {
  await tester.enterText(nameField, name);
  await tester.enterText(emailField, email);
  await tester.enterText(passwordField, password);
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(createButton);
  await tester.tap(createButton);
  await tester.pump();
}

void main() {
  testWidgets('shows name, email and password with a create button', (
    tester,
  ) async {
    await openRegister(tester);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(createButton, findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });

  group('inline validation (same rules and words as the API)', () {
    testWidgets('empty submit lists every missing field', (tester) async {
      await openRegister(tester);
      await submit(tester);
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(repo.registerCalls, isEmpty);
    });

    testWidgets('a malformed email is flagged', (tester) async {
      await openRegister(tester);
      await tester.enterText(emailField, 'a@b');
      await tester.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    for (final entry in {
      'Ab1': 'Password must be at least 8 characters',
      'OnlyLetters': 'Password must contain a number',
      '1234567890': 'Password must contain a letter',
    }.entries) {
      testWidgets('password "${entry.key}" shows "${entry.value}"', (
        tester,
      ) async {
        await openRegister(tester);
        await tester.enterText(passwordField, entry.key);
        await tester.pump();
        expect(find.text(entry.value), findsOneWidget);
        await fill(tester, password: entry.key);
        await submit(tester);
        expect(repo.registerCalls, isEmpty);
      });
    }

    testWidgets('an over-long name is flagged', (tester) async {
      await openRegister(tester);
      await tester.enterText(nameField, 'x' * 101);
      await tester.pump();
      expect(find.text('Name must be at most 100 characters'), findsOneWidget);
    });

    testWidgets('a compliant form sends nothing until submitted', (
      tester,
    ) async {
      await openRegister(tester);
      await fill(tester);
      await tester.pump();
      expect(find.textContaining('must'), findsNothing);
      expect(repo.registerCalls, isEmpty);
    });
  });

  group('submitting', () {
    testWidgets('success signs in, saves the session and opens Home', (
      tester,
    ) async {
      await openRegister(tester);
      repo.onRegister = (_, _, _) async => authResult();

      await fill(tester, name: '  Ada Lovelace ', email: ' ada@example.com ');
      await submit(tester);
      await tester.pumpAndSettle();

      expect(repo.registerCalls.single.name, 'Ada Lovelace');
      expect(repo.registerCalls.single.email, 'ada@example.com');
      expect(repo.registerCalls.single.password, 'Sup3rSecret');
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(store.session!.user, testUser);
    });

    testWidgets('repeated taps while in flight send exactly one request', (
      tester,
    ) async {
      await openRegister(tester);
      final pending = Completer<AuthResult>();
      repo.onRegister = (_, _, _) => pending.future;

      await fill(tester);
      await submit(tester);

      final button = tester.widget<FilledButton>(
        find.byType(FilledButton).first,
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(FilledButton).first, warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repo.registerCalls, hasLength(1));

      pending.complete(authResult());
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('server errors', () {
    testWidgets('EMAIL_TAKEN appears on the email field, not as a banner', (
      tester,
    ) async {
      await openRegister(tester);
      repo.onRegister = (_, _, _) async => throw const ConflictFailure(
        code: 'EMAIL_TAKEN',
        message: 'An account with this email already exists',
      );

      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('An account with this email already exists'),
        findsOneWidget,
      );
      // Shown under the email field, so there is no banner or retry button.
      expect(find.text('Try again'), findsNothing);
      expect(find.byType(MessageBanner), findsNothing);
      // Everything the user typed is still there.
      final name = tester.widget<EditableText>(
        find.descendant(of: nameField, matching: find.byType(EditableText)),
      );
      expect(name.controller.text, 'Ada Lovelace');
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the email message clears when the email is edited', (
      tester,
    ) async {
      await openRegister(tester);
      repo.onRegister = (_, _, _) async => throw const ConflictFailure(
        code: 'EMAIL_TAKEN',
        message: 'An account with this email already exists',
      );
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('An account with this email already exists'),
        findsOneWidget,
      );

      await tester.enterText(emailField, 'ada2@example.com');
      await tester.pump();
      expect(
        find.text('An account with this email already exists'),
        findsNothing,
      );
    });

    testWidgets('server validation messages land on their own fields', (
      tester,
    ) async {
      await openRegister(tester);
      repo.onRegister = (_, _, _) async => throw const ValidationFailure(
        fieldErrors: {
          'email': 'Enter a valid email address',
          'password': 'Password must contain a number',
        },
      );
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Password must contain a number'), findsOneWidget);
    });

    testWidgets('offline: readable message, retry, and the form is kept', (
      tester,
    ) async {
      await openRegister(tester);
      var attempt = 0;
      repo.onRegister = (_, _, _) async {
        attempt++;
        if (attempt == 1) throw const NetworkFailure();
        return authResult();
      };

      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining("Can't reach the server"), findsOneWidget);

      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(repo.registerCalls, hasLength(2));
      expect(repo.registerCalls.last.email, 'ada@example.com');
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a server error is readable and retryable', (tester) async {
      await openRegister(tester);
      repo.onRegister = (_, _, _) async => throw const ServerFailure();
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  testWidgets('"I already have an account" returns to sign in', (tester) async {
    await openRegister(tester);
    await tester.ensureVisible(find.text('I already have an account'));
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('fits a 320 dp screen with 2x text without overflow', (
    tester,
  ) async {
    useScreen(tester, width: 320, height: 640, textScale: 2.0);
    repo = FakeAuthRepository();
    await tester.pumpWidget(
      servoraAppWithRealSession(
        FakeTokenStore(),
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      createButton,
      100,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(createButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
