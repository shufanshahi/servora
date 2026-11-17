import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/domain/app_user.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';
import 'package:servora/core/session/token_store.dart';
import 'package:servora/features/profile/data/profile_repository.dart';
import 'package:servora/features/profile/presentation/profile_controller.dart';

import '../../support/fake_profile_repository.dart';
import '../../support/fake_token_store.dart';
import '../../support/fixtures.dart';

void main() {
  late FakeProfileRepository repo;
  late FakeTokenStore store;
  late ProviderContainer container;

  setUp(() async {
    repo = FakeProfileRepository();
    store = FakeTokenStore(storedSession());
    container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        tokenStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 17, 12)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.notifier).restore();
    repo.meCalls = 0; // the restore check is not what these tests are about
  });

  AppUser sessionUser() =>
      (container.read(sessionProvider) as SessionAuthenticated).user;
  ProfileController controller() =>
      container.read(profileControllerProvider.notifier);
  ProfileFormState form() => container.read(profileControllerProvider);

  group('load', () {
    test('fetches the latest details into the session', () async {
      repo.onMe = () async => testUser.copyWith(name: 'Ada King');
      await controller().load();
      expect(repo.meCalls, 1);
      expect(sessionUser().name, 'Ada King');
      expect(store.session!.user.name, 'Ada King'); // saved for next launch
    });

    test('a failed load keeps the cached details and shows no error', () async {
      repo.onMe = () async => throw const NetworkFailure();
      await controller().load();
      expect(sessionUser(), testUser);
      expect(form().failure, isNull);
    });
  });

  group('save', () {
    test('success updates the session and the saved copy', () async {
      final saved = await controller().save(
        name: '  Ada King ',
        phone: ' +1 555 123 4567 ',
      );
      expect(saved, isTrue);
      expect(repo.updateCalls.single.name, '  Ada King ');
      expect(sessionUser().name, 'Ada King');
      expect(sessionUser().phone, '+1 555 123 4567');
      expect(store.session!.user.name, 'Ada King');
      expect(form().isSaving, isFalse);
      expect(form().failure, isNull);
    });

    test('an empty phone removes the number', () async {
      await controller().save(name: 'Ada', phone: '+1 555 123 4567');
      await controller().save(name: 'Ada', phone: '  ');
      expect(sessionUser().phone, isNull);
    });

    test(
      'a network failure keeps the session as it was and reports it',
      () async {
        repo.onUpdate = (_, _) async => throw const NetworkFailure();
        final saved = await controller().save(name: 'Ada King', phone: '');
        expect(saved, isFalse);
        expect(form().failure, isA<NetworkFailure>());
        expect(sessionUser(), testUser);
        expect(store.session!.user, testUser);
        expect(form().isSaving, isFalse);
      },
    );

    test('field errors from the server are kept per field', () async {
      repo.onUpdate = (_, _) async => throw const ValidationFailure(
        fieldErrors: {'name': 'Name is required'},
      );
      expect(await controller().save(name: '', phone: ''), isFalse);
      expect(form().fieldErrors, {'name': 'Name is required'});
      expect(form().failure, isNull);

      controller().clearFieldError('name');
      expect(form().fieldErrors, isEmpty);
    });

    test('a second save while one is running is ignored', () async {
      final gate = Completer<AppUser>();
      repo.onUpdate = (_, _) => gate.future;
      final first = controller().save(name: 'A', phone: '');
      expect(form().isSaving, isTrue);
      expect(await controller().save(name: 'B', phone: ''), isFalse);
      gate.complete(testUser.copyWith(name: 'A'));
      expect(await first, isTrue);
      expect(repo.updateCalls, hasLength(1));
    });
  });

  group('change password', () {
    PasswordController password() =>
        container.read(passwordControllerProvider.notifier);
    ProfileFormState state() => container.read(passwordControllerProvider);

    test('success', () async {
      expect(
        await password().change(
          currentPassword: 'Old1pass',
          newPassword: 'New1pass!',
        ),
        isTrue,
      );
      expect(repo.passwordCalls.single, (
        current: 'Old1pass',
        next: 'New1pass!',
      ));
      expect(state().failure, isNull);
    });

    test(
      'a wrong current password is a field message, not a sign-out',
      () async {
        repo.onChangePassword = (_, _) async =>
            throw const UnauthenticatedFailure(code: 'INVALID_CREDENTIALS');
        expect(
          await password().change(
            currentPassword: 'bad',
            newPassword: 'New1pass!',
          ),
          isFalse,
        );
        expect(state().fieldErrors['currentPassword'], contains('incorrect'));
        expect(container.read(sessionProvider), isA<SessionAuthenticated>());
      },
    );

    test(
      'a weak new password shows the server message on that field',
      () async {
        repo.onChangePassword = (_, _) async => throw const ValidationFailure(
          fieldErrors: {'newPassword': 'Password must contain a number'},
        );
        await password().change(
          currentPassword: 'Old1pass',
          newPassword: 'nodigits',
        );
        expect(
          state().fieldErrors['newPassword'],
          'Password must contain a number',
        );
      },
    );

    test('other failures are reported', () async {
      repo.onChangePassword = (_, _) async => throw const ServerFailure();
      await password().change(
        currentPassword: 'Old1pass',
        newPassword: 'New1pass!',
      );
      expect(state().failure, isA<ServerFailure>());
    });
  });
}
