import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/session/token_store.dart';

import '../../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureTokenStore store;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = SecureTokenStore();
  });

  test('read returns null when nothing is stored', () async {
    expect(await store.read(), isNull);
  });

  test('a written session reads back with token, expiry and user', () async {
    final session = storedSession(expiresAt: DateTime.utc(2030, 5, 6, 7));
    await store.write(session);

    final loaded = await store.read();
    expect(loaded, isNotNull);
    expect(loaded!.accessToken, 'jwt-token');
    expect(loaded.expiresAt, DateTime.utc(2030, 5, 6, 7));
    expect(loaded.user, testUser);
  });

  test('clear removes the token and the cached user', () async {
    await store.write(storedSession());
    await store.clear();
    expect(await store.read(), isNull);
    // Nothing is left behind in the underlying storage.
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });

  test('a later write replaces the earlier one', () async {
    await store.write(storedSession(token: 'first'));
    await store.write(storedSession(token: 'second'));
    expect((await store.read())!.accessToken, 'second');
  });

  group('unreadable data', () {
    for (final entry in {
      'not json': 'this is not json',
      'wrong shape': jsonEncode({'hello': 'world'}),
      'missing user': jsonEncode({
        'accessToken': 'x',
        'expiresAt': '2099-01-01T00:00:00Z',
      }),
      'bad date': jsonEncode({
        'accessToken': 'x',
        'expiresAt': 'yesterday',
        'user': testUser.toJson(),
      }),
    }.entries) {
      test('${entry.key}: treated as signed out and removed', () async {
        FlutterSecureStorage.setMockInitialValues({
          'servora.session': entry.value,
        });
        store = SecureTokenStore();

        expect(await store.read(), isNull);
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
      });
    }
  });
}
