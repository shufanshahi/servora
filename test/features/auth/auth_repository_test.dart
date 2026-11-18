import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';
import 'package:servora/features/auth/data/auth_repository.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/fixtures.dart';

Map<String, dynamic> errorBody(
  String code,
  String message, {
  List<Map<String, String>>? details,
}) => {
  'success': false,
  'error': {'code': code, 'message': message, 'details': ?details},
};

void main() {
  late FakeHttpAdapter adapter;
  late AuthRepository repository;
  var unauthorizedCalls = 0;

  setUp(() {
    adapter = FakeHttpAdapter();
    unauthorizedCalls = 0;
    repository = AuthRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        // A token exists, to prove auth calls never send it or react to its 401s.
        tokenProvider: () async => 'stale-token',
        onUnauthorized: () => unauthorizedCalls++,
        httpClientAdapter: adapter,
      ),
    );
  });

  Future<AppFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on AppFailure catch (failure) {
      return failure;
    }
    fail('expected an AppFailure');
  }

  group('register', () {
    test(
      'posts the details and returns the user with token and expiry',
      () async {
        adapter.reply(201, {'success': true, 'data': authPayload()});

        final result = await repository.register(
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          password: 'Sup3rSecret',
        );

        expect(adapter.lastRequest.method, 'POST');
        expect(adapter.lastRequest.uri.path, '/auth/register');
        expect(adapter.lastRequest.data, {
          'name': 'Ada Lovelace',
          'email': 'ada@example.com',
          'password': 'Sup3rSecret',
        });
        expect(result.user, testUser);
        expect(result.accessToken, 'jwt-token');
        expect(result.expiresAt, DateTime.utc(2099));
      },
    );

    test('never sends an Authorization header', () async {
      adapter.reply(201, {'success': true, 'data': authPayload()});
      await repository.register(
        name: 'A',
        email: 'a@b.co',
        password: 'abcdefg1',
      );
      expect(adapter.lastRequest.headers.containsKey('Authorization'), isFalse);
    });

    test('EMAIL_TAKEN becomes a ConflictFailure with its code', () async {
      adapter.reply(
        409,
        errorBody('EMAIL_TAKEN', 'An account with this email already exists'),
      );
      final failure = await failureOf(
        repository.register(name: 'A', email: 'a@b.co', password: 'abcdefg1'),
      );
      expect(failure, isA<ConflictFailure>());
      expect(failure.code, 'EMAIL_TAKEN');
    });

    test('validation errors carry per-field messages', () async {
      adapter.reply(
        422,
        errorBody(
          'VALIDATION_ERROR',
          'Validation failed',
          details: [
            {'field': 'email', 'message': 'Enter a valid email address'},
            {'field': 'password', 'message': 'Password must contain a number'},
          ],
        ),
      );
      final failure = await failureOf(
        repository.register(name: 'A', email: 'x', password: 'abcdefgh'),
      );
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fieldErrors, {
        'email': 'Enter a valid email address',
        'password': 'Password must contain a number',
      });
    });

    test('a malformed success body becomes an UnknownFailure', () async {
      adapter.reply(201, {
        'success': true,
        'data': {'unexpected': true},
      });
      final failure = await failureOf(
        repository.register(name: 'A', email: 'a@b.co', password: 'abcdefg1'),
      );
      expect(failure, isA<UnknownFailure>());
    });
  });

  group('login', () {
    test('posts the credentials and returns the result', () async {
      adapter.reply(200, {'success': true, 'data': authPayload()});

      final result = await repository.login(
        email: 'ada@example.com',
        password: 'Sup3rSecret',
      );

      expect(adapter.lastRequest.uri.path, '/auth/login');
      expect(adapter.lastRequest.data, {
        'email': 'ada@example.com',
        'password': 'Sup3rSecret',
      });
      expect(result.user.email, 'ada@example.com');
      expect(result.accessToken, 'jwt-token');
    });

    test(
      'wrong credentials: friendly message and the session is untouched',
      () async {
        adapter.reply(
          401,
          errorBody('INVALID_CREDENTIALS', 'Incorrect email or password'),
        );
        final failure = await failureOf(
          repository.login(email: 'ada@example.com', password: 'nope'),
        );
        expect(failure, isA<UnauthenticatedFailure>());
        expect(failure.code, 'INVALID_CREDENTIALS');
        expect(failure.userMessage, 'Incorrect email or password');
        expect(unauthorizedCalls, 0);
      },
    );

    test('rate limiting becomes a RateLimitedFailure', () async {
      adapter.reply(429, errorBody('RATE_LIMITED', 'Too many requests'));
      expect(
        await failureOf(repository.login(email: 'a@b.co', password: 'x')),
        isA<RateLimitedFailure>(),
      );
    });

    test('offline becomes a NetworkFailure', () async {
      adapter.fail(
        (o) => DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
          error: const SocketException('offline'),
        ),
      );
      expect(
        await failureOf(repository.login(email: 'a@b.co', password: 'x')),
        isA<NetworkFailure>(),
      );
    });

    test('a server error becomes a ServerFailure', () async {
      adapter.reply(500, errorBody('INTERNAL_ERROR', 'Something went wrong'));
      expect(
        await failureOf(repository.login(email: 'a@b.co', password: 'x')),
        isA<ServerFailure>(),
      );
    });
  });
}
