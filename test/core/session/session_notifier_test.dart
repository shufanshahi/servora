import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';
import 'package:servora/core/session/token_store.dart';

import 'package:servora/features/profile/data/profile_repository.dart';

import '../../support/fake_profile_repository.dart';
import '../../support/fake_token_store.dart';
import '../../support/fixtures.dart';

final now = DateTime.utc(2026, 11, 17, 12);

ProviderContainer makeContainer(
  FakeTokenStore store, {
  FakeProfileRepository? profile,
}) {
  final container = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      profileRepositoryProvider.overrideWithValue(
        profile ?? FakeProfileRepository(),
      ),
      clockProvider.overrideWithValue(() => now),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<SessionState> restored(ProviderContainer container) async {
  await container.read(sessionProvider.notifier).restore();
  return container.read(sessionProvider);
}

void main() {
  group('restore on launch', () {
    test('starts unknown, before the saved session has been read', () {
      final container = makeContainer(FakeTokenStore());
      expect(container.read(sessionProvider), isA<SessionUnknown>());
      expect(container.read(sessionProvider).status, AuthStatus.unknown);
    });

    test('nothing saved: signed out, with no message', () async {
      final state = await restored(makeContainer(FakeTokenStore()));
      expect(state, isA<SessionUnauthenticated>());
      expect((state as SessionUnauthenticated).message, isNull);
    });

    test('a valid saved session signs the user straight in', () async {
      final store = FakeTokenStore(
        storedSession(expiresAt: now.add(const Duration(days: 3))),
      );
      final state = await restored(makeContainer(store));

      expect(state, isA<SessionAuthenticated>());
      final session = state as SessionAuthenticated;
      expect(session.user, testUser);
      expect(session.accessToken, 'jwt-token');
      expect(store.clears, 0);
    });

    test(
      'an expired saved token is cleared and the user is signed out',
      () async {
        final store = FakeTokenStore(
          storedSession(expiresAt: now.subtract(const Duration(minutes: 1))),
        );
        final state = await restored(makeContainer(store));

        expect(state, isA<SessionUnauthenticated>());
        expect(
          (state as SessionUnauthenticated).message,
          sessionExpiredMessage,
        );
        expect(store.session, isNull);
        expect(store.clears, 1);
      },
    );

    test('a token expiring exactly now counts as expired', () async {
      final store = FakeTokenStore(storedSession(expiresAt: now));
      expect(
        await restored(makeContainer(store)),
        isA<SessionUnauthenticated>(),
      );
    });

    test('a broken keystore starts signed out instead of crashing', () async {
      final store = FakeTokenStore()..failReads = true;
      expect(
        await restored(makeContainer(store)),
        isA<SessionUnauthenticated>(),
      );
    });

    test('restore runs only once however often it is called', () async {
      final store = FakeTokenStore(
        storedSession(expiresAt: now.add(const Duration(days: 1))),
      );
      final container = makeContainer(store);
      final notifier = container.read(sessionProvider.notifier);
      await Future.wait([
        notifier.restore(),
        notifier.restore(),
        notifier.restore(),
      ]);
      expect(container.read(sessionProvider), isA<SessionAuthenticated>());
    });

    test('restores by itself shortly after the app starts', () async {
      final store = FakeTokenStore(
        storedSession(expiresAt: now.add(const Duration(days: 1))),
      );
      final container = makeContainer(store);
      container.listen(sessionProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sessionProvider), isA<SessionAuthenticated>());
    });
  });

  group('signIn', () {
    test('signs in and saves the token, expiry and user', () async {
      final store = FakeTokenStore();
      final container = makeContainer(store);
      await container.read(sessionProvider.notifier).restore();

      await container
          .read(sessionProvider.notifier)
          .signIn(authResult().toStoredSession());

      final state = container.read(sessionProvider);
      expect(state, isA<SessionAuthenticated>());
      expect((state as SessionAuthenticated).user, testUser);
      expect(store.session!.accessToken, 'jwt-token');
      expect(store.session!.user, testUser);
    });
  });

  test(
    'signIn still signs in for this run if the keystore refuses the write',
    () async {
      final store = FakeTokenStore()..failWrites = true;
      final container = makeContainer(store);
      await container.read(sessionProvider.notifier).restore();

      await container
          .read(sessionProvider.notifier)
          .signIn(authResult().toStoredSession());

      expect(container.read(sessionProvider), isA<SessionAuthenticated>());
      expect(store.session, isNull);
    },
  );

  group('logout', () {
    test('signs out and removes the token and cached user', () async {
      final store = FakeTokenStore(
        storedSession(expiresAt: now.add(const Duration(days: 1))),
      );
      final container = makeContainer(store);
      await container.read(sessionProvider.notifier).restore();
      expect(container.read(sessionProvider), isA<SessionAuthenticated>());

      await container.read(sessionProvider.notifier).logout();

      final state = container.read(sessionProvider);
      expect(state, isA<SessionUnauthenticated>());
      expect((state as SessionUnauthenticated).message, isNull);
      expect(store.session, isNull);
    });

    test('a failing keystore cannot keep the user signed in', () async {
      final store = FakeTokenStore(
        storedSession(expiresAt: now.add(const Duration(days: 1))),
      );
      final container = makeContainer(store);
      await container.read(sessionProvider.notifier).restore();
      store.failClears = true;

      await container.read(sessionProvider.notifier).logout();

      expect(container.read(sessionProvider), isA<SessionUnauthenticated>());
    });
  });

  group('expire (a request was rejected with 401)', () {
    test(
      'signs out with the session-expired message and clears storage',
      () async {
        final store = FakeTokenStore(
          storedSession(expiresAt: now.add(const Duration(days: 1))),
        );
        final container = makeContainer(store);
        await container.read(sessionProvider.notifier).restore();

        await container.read(sessionProvider.notifier).expire();

        final state = container.read(sessionProvider);
        expect(state, isA<SessionUnauthenticated>());
        expect(
          (state as SessionUnauthenticated).message,
          sessionExpiredMessage,
        );
        expect(store.session, isNull);
      },
    );

    test(
      'is ignored when nobody is signed in (late response after logout)',
      () async {
        final store = FakeTokenStore();
        final container = makeContainer(store);
        await container.read(sessionProvider.notifier).restore();
        final before = container.read(sessionProvider);

        await container.read(sessionProvider.notifier).expire();

        expect(container.read(sessionProvider), same(before));
        expect(
          (container.read(sessionProvider) as SessionUnauthenticated).message,
          isNull,
        );
      },
    );
  });

  group('restore validates the session with the server', () {
    FakeTokenStore valid() => FakeTokenStore(
      storedSession(expiresAt: now.add(const Duration(days: 3))),
    );

    test('asks the server once and stays signed in when it agrees', () async {
      final profile = FakeProfileRepository();
      final container = makeContainer(valid(), profile: profile);
      final state = await restored(container);
      expect(profile.meCalls, 1);
      expect(state, isA<SessionAuthenticated>());
    });

    test('a 401 ends the session and clears the stored token', () async {
      final store = valid();
      final profile = FakeProfileRepository()
        ..onMe = () async => throw const UnauthenticatedFailure();
      final state = await restored(makeContainer(store, profile: profile));

      expect(state, isA<SessionUnauthenticated>());
      expect((state as SessionUnauthenticated).message, sessionExpiredMessage);
      expect(store.session, isNull);
      expect(store.clears, 1);
    });

    test('a user deleted on the server is signed out too', () async {
      final store = valid();
      final profile = FakeProfileRepository()
        ..onMe = () async => throw const UnauthenticatedFailure(
          message: 'Account no longer exists',
        );
      expect(
        await restored(makeContainer(store, profile: profile)),
        isA<SessionUnauthenticated>(),
      );
      expect(store.session, isNull);
    });

    test('being offline keeps the user signed in', () async {
      final store = valid();
      final profile = FakeProfileRepository()
        ..onMe = () async => throw const NetworkFailure();
      final state = await restored(makeContainer(store, profile: profile));
      expect(state, isA<SessionAuthenticated>());
      expect(store.session, isNotNull);
      expect(store.clears, 0);
    });

    test('a server error keeps the user signed in', () async {
      final profile = FakeProfileRepository()
        ..onMe = () async => throw const ServerFailure();
      expect(
        await restored(makeContainer(valid(), profile: profile)),
        isA<SessionAuthenticated>(),
      );
    });

    test('fresher details replace the saved ones', () async {
      final store = valid();
      final profile = FakeProfileRepository()
        ..onMe = () async => testUser.copyWith(name: 'Renamed Elsewhere');
      final state = await restored(makeContainer(store, profile: profile));
      expect((state as SessionAuthenticated).user.name, 'Renamed Elsewhere');
      expect(store.session!.user.name, 'Renamed Elsewhere');
    });

    test(
      'a locally expired token is cleared without asking the server',
      () async {
        final store = FakeTokenStore(
          storedSession(expiresAt: now.subtract(const Duration(minutes: 1))),
        );
        final profile = FakeProfileRepository();
        await restored(makeContainer(store, profile: profile));
        expect(profile.meCalls, 0);
        expect(store.session, isNull);
      },
    );
  });
}
