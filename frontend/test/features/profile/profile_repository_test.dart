import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/domain/app_user.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';
import 'package:servora/features/profile/data/profile_repository.dart';
import 'package:servora/features/profile/domain/profile_validators.dart';

import '../../support/fake_http_adapter.dart';

Map<String, dynamic> userJson({String? phone}) => {
  'id': 'u-1',
  'name': 'Ada Lovelace',
  'email': 'ada@example.com',
  'phone': phone,
  'createdAt': '2026-11-17T10:00:00.000Z',
};

void main() {
  late FakeHttpAdapter adapter;
  late ProfileRepository repository;

  setUp(() {
    adapter = FakeHttpAdapter();
    repository = ProfileRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        tokenProvider: () async => 'tok',
        httpClientAdapter: adapter,
      ),
    );
  });

  group('AppUser', () {
    test(
      'parses the phone, and tolerates its absence (older saved sessions)',
      () {
        expect(AppUser.fromJson(userJson(phone: '+1 555')).phone, '+1 555');
        final legacy = userJson()..remove('phone');
        expect(AppUser.fromJson(legacy).phone, isNull);
      },
    );

    test('round-trips through JSON', () {
      final user = AppUser.fromJson(userJson(phone: '555-123-4567'));
      expect(AppUser.fromJson(user.toJson()), user);
    });

    test('copyWith can change or clear the phone', () {
      final user = AppUser.fromJson(userJson(phone: '555-123-4567'));
      expect(user.copyWith(name: 'New').phone, '555-123-4567');
      expect(user.copyWith(clearPhone: true).phone, isNull);
    });
  });

  group('repository', () {
    test('me reads the current user with the token', () async {
      adapter.reply(200, {
        'success': true,
        'data': userJson(phone: '555-123-4567'),
      });
      final user = await repository.me();
      expect(adapter.lastRequest.path, '/users/me');
      expect(adapter.lastRequest.headers['Authorization'], 'Bearer tok');
      expect(user.phone, '555-123-4567');
    });

    test('update patches trimmed name and phone', () async {
      adapter.reply(200, {'success': true, 'data': userJson(phone: '555')});
      await repository.update(name: '  Ada  ', phone: ' 555 ');
      expect(adapter.lastRequest.method, 'PATCH');
      expect(adapter.lastRequest.data, {'name': 'Ada', 'phone': '555'});
    });

    test('a blank phone is sent as null to clear it', () async {
      adapter.reply(200, {'success': true, 'data': userJson()});
      await repository.update(name: 'Ada', phone: '   ');
      expect((adapter.lastRequest.data as Map)['phone'], isNull);
    });

    test('a validation error carries field messages', () async {
      adapter.reply(422, {
        'success': false,
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Validation failed',
          'details': [
            {'field': 'name', 'message': 'Name is required'},
          ],
        },
      });
      try {
        await repository.update(name: '', phone: null);
        fail('expected a failure');
      } on ValidationFailure catch (failure) {
        expect(failure.fieldErrors['name'], 'Name is required');
      }
    });

    test('changePassword posts both passwords', () async {
      adapter.reply(200, {
        'success': true,
        'data': {'changed': true},
      });
      await repository.changePassword(currentPassword: 'a', newPassword: 'b');
      expect(adapter.lastRequest.path, '/users/me/password');
      expect(adapter.lastRequest.data, {
        'currentPassword': 'a',
        'newPassword': 'b',
      });
    });

    test('a wrong current password is INVALID_CREDENTIALS and does not look like an expired session', () async {
      adapter.reply(401, {
        'success': false,
        'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Incorrect'},
      });
      try {
        await repository.changePassword(currentPassword: 'x', newPassword: 'y');
        fail('expected a failure');
      } on UnauthenticatedFailure catch (failure) {
        expect(failure.code, 'INVALID_CREDENTIALS');
      }
    });

    test('a malformed user is an unknown failure', () async {
      adapter.reply(200, {
        'success': true,
        'data': {'id': 1},
      });
      expect(repository.me(), throwsA(isA<UnknownFailure>()));
    });
  });

  group('ProfileValidators.phone', () {
    test('accepts blank and common formats', () {
      for (final ok in [
        '',
        '  ',
        '+1 555 123 4567',
        '(555) 123-4567',
        '555.123.4567',
        '+442079460958',
      ]) {
        expect(ProfileValidators.phone(ok), isNull, reason: ok);
      }
    });

    test('rejects letters, too few or too many digits', () {
      for (final bad in [
        'abc',
        '12345',
        '555 abc 1234',
        '1' * 16,
        '+++',
        '(5',
      ]) {
        expect(
          ProfileValidators.phone(bad),
          ProfileValidators.phoneMessage,
          reason: bad,
        );
      }
    });
  });
}
