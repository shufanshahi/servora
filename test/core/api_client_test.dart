import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';

import '../support/fake_http_adapter.dart';

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
  late int unauthorizedCalls;
  String? token;

  ApiClient makeClient() => ApiClient(
    baseUrl: 'http://api.test',
    tokenProvider: () async => token,
    onUnauthorized: () => unauthorizedCalls++,
    httpClientAdapter: adapter,
  );

  setUp(() {
    adapter = FakeHttpAdapter();
    unauthorizedCalls = 0;
    token = null;
  });

  Future<AppFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on AppFailure catch (failure) {
      return failure;
    }
    fail('expected an AppFailure to be thrown');
  }

  group('success', () {
    test('unwraps the envelope and returns the data', () async {
      adapter.reply(200, {
        'success': true,
        'data': {'id': 'abc', 'name': 'Haircut'},
      });
      final response = await makeClient().get('/services/abc');
      expect(response.data, {'id': 'abc', 'name': 'Haircut'});
      expect(response.meta, isNull);
      expect(
        adapter.lastRequest.uri.toString(),
        'http://api.test/services/abc',
      );
    });

    test('exposes pagination meta for list responses', () async {
      adapter.reply(200, {
        'success': true,
        'data': [
          {'id': 1},
          {'id': 2},
        ],
        'meta': {'page': 1, 'limit': 2, 'total': 5},
      });
      final response = await makeClient().get('/services', query: {'page': 1});
      expect(response.data, hasLength(2));
      expect(response.meta!.total, 5);
      expect(response.meta!.hasMore, isTrue);
      expect(adapter.lastRequest.queryParameters, {'page': 1});
    });

    test('sends JSON bodies for post and patch', () async {
      adapter
        ..reply(201, {
          'success': true,
          'data': {'ok': true},
        })
        ..reply(200, {
          'success': true,
          'data': {'ok': true},
        });
      final client = makeClient();
      await client.post('/things', body: {'name': 'x'});
      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.data, {'name': 'x'});
      await client.patch('/things/1', body: {'name': 'y'});
      expect(adapter.lastRequest.method, 'PATCH');
    });

    test(
      'a 2xx that is not in the envelope becomes an UnknownFailure',
      () async {
        adapter.reply(200, {'hello': 'world'});
        expect(await failureOf(makeClient().get('/x')), isA<UnknownFailure>());
      },
    );
  });

  group('authorization header', () {
    test('adds the bearer token when one exists', () async {
      token = 'jwt-123';
      adapter.reply(200, {'success': true, 'data': null});
      await makeClient().get('/users/me');
      expect(adapter.lastRequest.headers['Authorization'], 'Bearer jwt-123');
    });

    test('omits the header when signed out', () async {
      adapter.reply(200, {'success': true, 'data': null});
      await makeClient().get('/services');
      expect(adapter.lastRequest.headers.containsKey('Authorization'), isFalse);
    });

    test(
      'omits the header for unauthenticated calls even with a token',
      () async {
        token = 'jwt-123';
        adapter.reply(200, {'success': true, 'data': null});
        await makeClient().post('/auth/login', authenticated: false);
        expect(
          adapter.lastRequest.headers.containsKey('Authorization'),
          isFalse,
        );
      },
    );
  });

  group('error-code mapping', () {
    test(
      '401 with a token: UnauthenticatedFailure and the 401 callback',
      () async {
        token = 'expired';
        adapter.reply(
          401,
          errorBody('UNAUTHENTICATED', 'Authentication required'),
        );
        final failure = await failureOf(makeClient().get('/users/me'));
        expect(failure, isA<UnauthenticatedFailure>());
        expect(failure.userMessage, contains('session has expired'));
        expect(unauthorizedCalls, 1);
      },
    );

    test('401 wrong password: friendly message, no session clearing', () async {
      adapter.reply(
        401,
        errorBody('INVALID_CREDENTIALS', 'Incorrect email or password'),
      );
      final failure = await failureOf(
        makeClient().post('/auth/login', authenticated: false),
      );
      expect(failure, isA<UnauthenticatedFailure>());
      expect(failure.code, 'INVALID_CREDENTIALS');
      expect(failure.userMessage, 'Incorrect email or password');
      expect(unauthorizedCalls, 0);
    });

    test('401 without a token does not fire the callback', () async {
      adapter.reply(
        401,
        errorBody('UNAUTHENTICATED', 'Authentication required'),
      );
      await failureOf(makeClient().get('/users/me'));
      expect(unauthorizedCalls, 0);
    });

    test('403 -> ForbiddenFailure', () async {
      adapter.reply(403, errorBody('FORBIDDEN', 'No'));
      expect(await failureOf(makeClient().get('/x')), isA<ForbiddenFailure>());
    });

    test('404 -> NotFoundFailure', () async {
      adapter.reply(404, errorBody('NOT_FOUND', 'Missing'));
      expect(await failureOf(makeClient().get('/x')), isA<NotFoundFailure>());
    });

    test('409 -> ConflictFailure with code and server message', () async {
      adapter.reply(
        409,
        errorBody('SLOT_UNAVAILABLE', 'That time was just taken'),
      );
      final failure = await failureOf(makeClient().post('/appointments'));
      expect(failure, isA<ConflictFailure>());
      expect(failure.code, 'SLOT_UNAVAILABLE');
      expect(failure.userMessage, 'That time was just taken');
    });

    test('422 -> ValidationFailure with a per-field map', () async {
      adapter.reply(
        422,
        errorBody(
          'VALIDATION_ERROR',
          'Validation failed',
          details: [
            {'field': 'email', 'message': 'Invalid email'},
            {'field': 'password', 'message': 'Too short'},
            {'field': 'email', 'message': 'second message ignored'},
          ],
        ),
      );
      final failure = await failureOf(makeClient().post('/auth/register'));
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fieldErrors, {
        'email': 'Invalid email',
        'password': 'Too short',
      });
    });

    test('429 -> RateLimitedFailure', () async {
      adapter.reply(429, errorBody('RATE_LIMITED', 'Slow down'));
      expect(
        await failureOf(makeClient().get('/x')),
        isA<RateLimitedFailure>(),
      );
    });

    test('500 and 503 -> ServerFailure keeping the code', () async {
      adapter
        ..reply(500, errorBody('INTERNAL_ERROR', 'Something went wrong'))
        ..reply(503, errorBody('AI_UNAVAILABLE', 'Assistant unavailable'));
      final client = makeClient();
      expect(await failureOf(client.get('/x')), isA<ServerFailure>());
      final ai = await failureOf(client.post('/ai/chat'));
      expect(ai, isA<ServerFailure>());
      expect(ai.code, 'AI_UNAVAILABLE');
      expect(ai.userMessage, 'Something went wrong. Please try again.');
    });

    test(
      'a non-JSON error page maps by status and never leaks the body',
      () async {
        adapter.replyRaw(502, '<html>Bad gateway: internal host db-7</html>');
        final failure = await failureOf(makeClient().get('/x'));
        expect(failure, isA<ServerFailure>());
        expect(failure.userMessage, isNot(contains('db-7')));
      },
    );

    test('400 and other unexpected statuses -> UnknownFailure', () async {
      adapter.reply(400, errorBody('BAD_REQUEST', 'Malformed'));
      expect(await failureOf(makeClient().get('/x')), isA<UnknownFailure>());
    });
  });

  group('transport failures', () {
    test('timeout -> TimeoutFailure', () async {
      adapter.fail(
        (o) => DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: o,
        ),
      );
      final failure = await failureOf(makeClient().get('/x'));
      expect(failure, isA<TimeoutFailure>());
      expect(failure.isRetryable, isTrue);
    });

    test('connection timeout -> TimeoutFailure', () async {
      adapter.fail(
        (o) => DioException.connectionTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: o,
        ),
      );
      expect(await failureOf(makeClient().get('/x')), isA<TimeoutFailure>());
    });

    test('offline (connection error) -> NetworkFailure', () async {
      adapter.fail(
        (o) => DioException.connectionError(
          requestOptions: o,
          reason: 'Failed host lookup',
          error: const SocketException('Failed host lookup'),
        ),
      );
      final failure = await failureOf(makeClient().get('/x'));
      expect(failure, isA<NetworkFailure>());
      expect(failure.userMessage, contains("Can't reach the server"));
    });

    test('a raw SocketException is also treated as offline', () async {
      adapter.fail(
        (o) => DioException(
          requestOptions: o,
          error: const SocketException('Network is unreachable'),
        ),
      );
      expect(await failureOf(makeClient().get('/x')), isA<NetworkFailure>());
    });

    test('only AppFailure is ever thrown to callers', () async {
      adapter.fail(
        (o) => DioException(requestOptions: o, error: StateError('x')),
      );
      Object? thrown;
      try {
        await makeClient().get('/x');
      } catch (error) {
        thrown = error;
      }
      expect(thrown, isA<AppFailure>());
    });
  });
}
