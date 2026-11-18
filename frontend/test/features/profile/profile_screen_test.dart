import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/app.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/router/app_router.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';

import '../../support/app_harness.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_token_store.dart';
import '../../support/fixtures.dart';

late FakeProfileRepository repo;

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ServoraApp)));

Future<void> openProfile(
  WidgetTester tester, {
  FakeProfileRepository? repository,
  double width = 400,
  double height = 900,
  double textScale = 1,
}) async {
  useScreen(tester, width: width, height: height, textScale: textScale);
  repo = repository ?? FakeProfileRepository();
  await tester.pumpWidget(
    servoraApp(status: AuthStatus.authenticated, profileRepository: repo),
  );
  await tester.pumpAndSettle();
  await tester.tap(navTab('Profile'));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextFormField, label);
String textOf(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(field(label)).controller!.text;

/// Scrolls until [finder] is built, then brings it fully into view (it may first
/// appear only partly, under the floating navigation bar).
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder button(String label) => find.widgetWithText(FilledButton, label);
final saveButton = button('Save changes');

void main() {
  group('view', () {
    testWidgets('shows the user’s details, with email read-only', (
      tester,
    ) async {
      await openProfile(
        tester,
        repository: FakeProfileRepository(
          testUser.copyWith(phone: '+1 555 123 4567'),
        ),
      );
      // Session user comes from the fixed test session (no phone); the refresh brings it.
      expect(textOf(tester, 'Name'), 'Ada Lovelace');
      expect(textOf(tester, 'Email'), 'ada@example.com');
      expect(textOf(tester, 'Phone (optional)'), '+1 555 123 4567');
      expect(tester.widget<TextFormField>(field('Email')).enabled, isFalse);
      expect(find.text('A'), findsOneWidget); // avatar initial
    });

    testWidgets('quietly refreshes from the server when opened', (
      tester,
    ) async {
      await openProfile(tester);
      expect(repo.meCalls, greaterThanOrEqualTo(1));
    });

    testWidgets(
      'a failed refresh shows no error and keeps the cached details',
      (tester) async {
        await openProfile(
          tester,
          repository: FakeProfileRepository()
            ..onMe = () async => throw const NetworkFailure(),
        );
        expect(find.text(const NetworkFailure().userMessage), findsNothing);
        expect(textOf(tester, 'Name'), 'Ada Lovelace');
      },
    );
  });

  group('edit', () {
    testWidgets('saving shows a confirmation and the name appears everywhere', (
      tester,
    ) async {
      await openProfile(tester);
      await tester.enterText(field('Name'), '  Ada King ');
      await tester.enterText(field('Phone (optional)'), '+1 555 123 4567');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repo.updateCalls.single.phone, '+1 555 123 4567');
      expect(find.text('Profile updated'), findsOneWidget);
      // The header (and the session) carry the new name.
      expect(find.text('Ada King'), findsOneWidget);
      final session =
          containerOf(tester).read(sessionProvider) as SessionAuthenticated;
      expect(session.user.name, 'Ada King');
      expect(session.user.phone, '+1 555 123 4567');
    });

    testWidgets('an empty name is rejected inline and nothing is sent', (
      tester,
    ) async {
      await openProfile(tester);
      await tester.enterText(field('Name'), '   ');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsOneWidget);
      expect(repo.updateCalls, isEmpty);
    });

    testWidgets('an invalid phone is rejected inline', (tester) async {
      await openProfile(tester);
      await tester.enterText(field('Phone (optional)'), '12');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a valid phone number'), findsOneWidget);
      expect(repo.updateCalls, isEmpty);
    });

    testWidgets('letters cannot be typed into the phone field', (tester) async {
      await openProfile(tester);
      await tester.enterText(field('Phone (optional)'), '555abc123');
      expect(textOf(tester, 'Phone (optional)'), '555123');
    });

    testWidgets('a blank phone is allowed and clears the number', (
      tester,
    ) async {
      await openProfile(
        tester,
        repository: FakeProfileRepository(
          testUser.copyWith(phone: '555-123-4567'),
        ),
      );
      await tester.enterText(field('Phone (optional)'), '');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(repo.updateCalls.single.phone, '');
      expect(
        (containerOf(
          tester,
        ).read(sessionProvider) as SessionAuthenticated).user.phone,
        isNull,
      );
    });

    testWidgets('a failed save shows the error and keeps the edits', (
      tester,
    ) async {
      await openProfile(
        tester,
        repository: FakeProfileRepository()
          ..onUpdate = (_, _) async => throw const NetworkFailure(),
      );
      await tester.enterText(field('Name'), 'Ada King');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text(const NetworkFailure().userMessage), findsOneWidget);
      expect(textOf(tester, 'Name'), 'Ada King'); // not lost
      expect(find.text('Profile updated'), findsNothing);
      final session =
          containerOf(tester).read(sessionProvider) as SessionAuthenticated;
      expect(session.user.name, 'Ada Lovelace'); // not changed

      // Trying again works.
      repo.onUpdate = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Profile updated'), findsOneWidget);
    });

    testWidgets(
      'a server field error appears on that field and clears on edit',
      (tester) async {
        await openProfile(
          tester,
          repository: FakeProfileRepository()
            ..onUpdate = (_, _) async => throw const ValidationFailure(
              fieldErrors: {'name': 'Name is taken (example)'},
            ),
        );
        await tester.enterText(field('Name'), 'Ada King');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
        expect(find.text('Name is taken (example)'), findsOneWidget);
        await tester.enterText(field('Name'), 'Ada Kingsley');
        await tester.pump();
        expect(find.text('Name is taken (example)'), findsNothing);
      },
    );

    testWidgets(
      'the button shows progress and a second tap sends one request',
      (tester) async {
        final gate = Completer<void>();
        await openProfile(
          tester,
          repository: FakeProfileRepository()
            ..onUpdate = (name, phone) async {
              await gate.future;
              return testUser.copyWith(name: name);
            },
        );
        await tester.enterText(field('Name'), 'Ada King');
        await tester.tap(saveButton);
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byType(FilledButton).first, warnIfMissed: false);
        await tester.pump();
        expect(repo.updateCalls, hasLength(1));
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('Profile updated'), findsOneWidget);
      },
    );

    testWidgets(
      'fresher details from the server do not overwrite edits in progress',
      (tester) async {
        final gate = Completer<void>();
        await openProfile(
          tester,
          repository: FakeProfileRepository()
            ..onMe = () async {
              await gate.future;
              return testUser.copyWith(phone: '+1 555 000 1111');
            },
        );
        await tester.enterText(field('Name'), 'Typing in progress');
        gate.complete();
        await tester.pumpAndSettle();
        expect(textOf(tester, 'Name'), 'Typing in progress');
        // The untouched phone field did pick up the server value.
        expect(textOf(tester, 'Phone (optional)'), '+1 555 000 1111');
      },
    );
  });

  group('sign out', () {
    Future<void> openSignOutDialog(WidgetTester tester) async {
      final signOut = find.widgetWithText(OutlinedButton, 'Sign out');
      await scrollTo(tester, signOut);
      await tester.tap(signOut);
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
    }

    testWidgets('cancelling keeps the user signed in', (tester) async {
      final store = FakeTokenStore(storedSession());
      useScreen(tester, width: 400, height: 900);
      await tester.pumpWidget(
        servoraAppWithRealSession(
          store,
          profileRepository: FakeProfileRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(navTab('Profile'));
      await tester.pumpAndSettle();

      await openSignOutDialog(tester);
      await tester.tap(find.text('Stay signed in'));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(sessionProvider),
        isA<SessionAuthenticated>(),
      );
      expect(store.clears, 0);
      expect(store.session, isNotNull);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('confirming clears the session and returns to login', (
      tester,
    ) async {
      final store = FakeTokenStore(storedSession());
      useScreen(tester, width: 400, height: 900);
      await tester.pumpWidget(
        servoraAppWithRealSession(
          store,
          profileRepository: FakeProfileRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(navTab('Profile'));
      await tester.pumpAndSettle();

      await openSignOutDialog(tester);
      await tester.tap(button('Sign out'));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(sessionProvider),
        isA<SessionUnauthenticated>(),
      );
      expect(store.session, isNull);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        containerOf(tester)
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/login',
      );
    });
  });

  group('change password', () {
    Future<void> openForm(WidgetTester tester) async {
      final open = find.text('Change password');
      await scrollTo(tester, open);
      await tester.tap(open);
      await tester.pumpAndSettle();
    }

    testWidgets('is hidden until asked for', (tester) async {
      await openProfile(tester);
      expect(field('Current password'), findsNothing);
      await openForm(tester);
      expect(field('Current password'), findsOneWidget);
      expect(field('New password'), findsOneWidget);
    });

    testWidgets(
      'a wrong current password is explained and keeps the user signed in',
      (tester) async {
        await openProfile(
          tester,
          repository: FakeProfileRepository()
            ..onChangePassword = (_, _) async =>
                throw const UnauthenticatedFailure(code: 'INVALID_CREDENTIALS'),
        );
        await openForm(tester);
        await tester.enterText(field('Current password'), 'WrongPass1');
        await tester.enterText(field('New password'), 'N3wPassword!');
        await tester.tap(button('Update password'));
        await tester.pumpAndSettle();

        expect(find.text('Your current password is incorrect'), findsOneWidget);
        expect(
          containerOf(tester).read(sessionProvider),
          isA<SessionAuthenticated>(),
        );
        expect(find.text('Password changed'), findsNothing);
      },
    );

    testWidgets('success confirms and closes the form', (tester) async {
      await openProfile(tester);
      await openForm(tester);
      await tester.enterText(field('Current password'), 'Sup3rSecret');
      await tester.enterText(field('New password'), 'N3wPassword!');
      await tester.tap(button('Update password'));
      await tester.pumpAndSettle();

      expect(repo.passwordCalls.single, (
        current: 'Sup3rSecret',
        next: 'N3wPassword!',
      ));
      expect(find.text('Password changed'), findsOneWidget);
      expect(field('Current password'), findsNothing);
    });

    testWidgets('a weak new password is rejected inline without a request', (
      tester,
    ) async {
      await openProfile(tester);
      await openForm(tester);
      await tester.enterText(field('Current password'), 'Sup3rSecret');
      await tester.enterText(field('New password'), 'short');
      await tester.tap(button('Update password'));
      await tester.pumpAndSettle();
      expect(
        find.text('Password must be at least 8 characters'),
        findsOneWidget,
      );
      expect(repo.passwordCalls, isEmpty);
    });

    testWidgets('cancel hides the form and forgets what was typed', (
      tester,
    ) async {
      await openProfile(tester);
      await openForm(tester);
      await tester.enterText(field('Current password'), 'secret');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(field('Current password'), findsNothing);
      await openForm(tester);
      expect(textOf(tester, 'Current password'), '');
    });
  });

  group('layout', () {
    testWidgets(
      'no overflow at 320 dp with 3x text, including the password form',
      (tester) async {
        await openProfile(tester, width: 320, height: 640, textScale: 3);
        expect(tester.takeException(), isNull);
        final open = find.text('Change password');
        await scrollTo(tester, open);
        await tester.tap(open);
        await tester.pumpAndSettle();
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -300));
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('is a readable column on a tablet', (tester) async {
      await openProfile(tester, width: 1280, height: 900);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(field('Name')).width, lessThan(660));
    });
  });
}
