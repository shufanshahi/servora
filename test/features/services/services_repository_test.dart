import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';
import 'package:servora/features/services/data/services_repository.dart';
import 'package:servora/features/services/domain/service_filter.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/service_fixtures.dart';

void main() {
  late FakeHttpAdapter adapter;
  late ServicesRepository repository;

  setUp(() {
    adapter = FakeHttpAdapter();
    repository = ServicesRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        // A token exists, to prove the public catalogue never sends it.
        tokenProvider: () async => 'some-token',
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

  group('queryFor', () {
    test('a plain request carries only paging', () {
      expect(ServicesRepository.queryFor(), {'page': 1, 'limit': 20});
    });

    test('includes a trimmed search and a category', () {
      expect(
        ServicesRepository.queryFor(
          filter: const ServiceFilter(
            query: '  massage ',
            category: 'Wellness',
          ),
        ),
        {'q': 'massage', 'category': 'Wellness', 'page': 1, 'limit': 20},
      );
    });

    test('leaves out a blank search and a null category', () {
      final query = ServicesRepository.queryFor(
        filter: const ServiceFilter(query: '   '),
      );
      expect(query.containsKey('q'), isFalse);
      expect(query.containsKey('category'), isFalse);
    });

    test('featured is sent as text only when asked for', () {
      expect(ServicesRepository.queryFor(featured: true)['featured'], 'true');
      expect(ServicesRepository.queryFor().containsKey('featured'), isFalse);
    });

    test('carries the page and the page size', () {
      final query = ServicesRepository.queryFor(page: 3, limit: 5);
      expect(query['page'], 3);
      expect(query['limit'], 5);
    });
  });

  group('list', () {
    test(
      'requests /services with the filter and parses the real payload',
      () async {
        adapter.reply(200, realServicesPage());

        final page = await repository.list(
          filter: const ServiceFilter(query: 'massage', category: 'Wellness'),
          limit: 50,
        );

        expect(adapter.lastRequest.method, 'GET');
        expect(adapter.lastRequest.uri.path, '/services');
        expect(adapter.lastRequest.queryParameters, {
          'q': 'massage',
          'category': 'Wellness',
          'page': 1,
          'limit': 50,
        });
        expect(page.items, hasLength(10));
        expect(page.meta.total, 10);
        expect(page.meta.hasMore, isFalse);
      },
    );

    test('reports that there are more pages when there are', () async {
      adapter.reply(200, {
        'success': true,
        'data': [realServicesPage()['data'][0]],
        'meta': {'page': 1, 'limit': 1, 'total': 10},
      });
      final page = await repository.list(limit: 1);
      expect(page.items, hasLength(1));
      expect(page.meta.hasMore, isTrue);
    });

    test('an empty result is a normal, empty page', () async {
      adapter.reply(200, {
        'success': true,
        'data': <Object>[],
        'meta': {'page': 1, 'limit': 20, 'total': 0},
      });
      final page = await repository.list();
      expect(page.items, isEmpty);
      expect(page.meta.total, 0);
    });

    test('never sends the Authorization header, even when signed in', () async {
      adapter.reply(200, realServicesPage());
      await repository.list();
      expect(adapter.lastRequest.headers.containsKey('Authorization'), isFalse);
    });

    test('featured requests ask the API for featured services only', () async {
      adapter.reply(200, realServicesPage());
      await repository.list(featured: true, limit: 10);
      expect(adapter.lastRequest.queryParameters['featured'], 'true');
    });

    test('a response without paging details is an UnknownFailure', () async {
      adapter.reply(200, {'success': true, 'data': realServicesPage()['data']});
      expect(await failureOf(repository.list()), isA<UnknownFailure>());
    });

    test('a malformed service in the list is an UnknownFailure', () async {
      adapter.reply(200, {
        'success': true,
        'data': [
          {'id': 'x'},
        ],
        'meta': {'page': 1, 'limit': 20, 'total': 1},
      });
      expect(await failureOf(repository.list()), isA<UnknownFailure>());
    });

    test('a 422 becomes a ValidationFailure', () async {
      adapter.reply(422, {
        'success': false,
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Validation failed',
          'details': [
            {'field': 'query.minPrice', 'message': 'minPrice must be a number'},
          ],
        },
      });
      expect(await failureOf(repository.list()), isA<ValidationFailure>());
    });

    test('offline becomes a NetworkFailure', () async {
      adapter.fail(
        (o) => DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
          error: const SocketException('offline'),
        ),
      );
      expect(await failureOf(repository.list()), isA<NetworkFailure>());
    });

    test('a server error becomes a ServerFailure', () async {
      adapter.reply(500, {
        'success': false,
        'error': {'code': 'INTERNAL_ERROR', 'message': 'Something went wrong'},
      });
      expect(await failureOf(repository.list()), isA<ServerFailure>());
    });
  });

  group('get', () {
    test('requests /services/:id and parses the real detail payload', () async {
      adapter.reply(200, realServiceDetail());
      final id =
          (realServiceDetail()['data'] as Map<String, dynamic>)['id'] as String;

      final service = await repository.get(id);

      expect(adapter.lastRequest.uri.path, '/services/$id');
      expect(service.id, id);
      expect(service.name, isNotEmpty);
      expect(adapter.lastRequest.headers.containsKey('Authorization'), isFalse);
    });

    test('an id is encoded so it cannot change the path', () async {
      adapter.reply(404, {
        'success': false,
        'error': {'code': 'NOT_FOUND', 'message': 'Service not found'},
      });
      await failureOf(repository.get('a/b?c=d'));
      expect(adapter.lastRequest.uri.path, '/services/a%2Fb%3Fc%3Dd');
    });

    test('an unknown service is a NotFoundFailure', () async {
      adapter.reply(404, {
        'success': false,
        'error': {'code': 'NOT_FOUND', 'message': 'Service not found'},
      });
      expect(await failureOf(repository.get('nope')), isA<NotFoundFailure>());
    });

    test('a malformed detail payload is an UnknownFailure', () async {
      adapter.reply(200, {
        'success': true,
        'data': {'unexpected': true},
      });
      expect(await failureOf(repository.get('x')), isA<UnknownFailure>());
    });
  });
}
