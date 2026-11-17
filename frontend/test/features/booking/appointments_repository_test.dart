import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/domain/booking_status.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';
import 'package:servora/features/booking/data/appointments_repository.dart';
import 'package:servora/features/booking/domain/appointment.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_http_adapter.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  late FakeHttpAdapter adapter;
  late AppointmentsRepository repository;

  setUp(() {
    adapter = FakeHttpAdapter();
    repository = AppointmentsRepository(
      ApiClient(
        baseUrl: 'http://api.test',
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

  group('models parse the real API payloads', () {
    test('availability', () {
      final data = realAvailability()['data'] as Map<String, dynamic>;
      final availability = Availability.fromJson(data);
      expect(availability.timeZone, 'UTC');
      expect(availability.durationMinutes, 60);
      expect(availability.slots, hasLength(15));
      final first = availability.slots.first;
      expect(first.label, '09:00');
      expect(first.available, isTrue);
      expect(first.startsAt, endsWith('Z'));
      expect(availability.hasAvailableSlot, isTrue);
    });

    test('a created appointment', () {
      final appointment = Appointment.fromJson(
        realAppointmentCreated()['data'] as Map<String, dynamic>,
      );
      expect(appointment.status, BookingStatus.pending);
      expect(appointment.service.name, 'Swedish Massage');
      expect(appointment.price, 65);
      expect(appointment.note, 'Please use unscented oil');
      expect(appointment.endsAt.difference(appointment.startsAt).inMinutes, 60);
      expect(appointment.startsAt.isUtc, isTrue);
      expect(appointment.cancelledAt, isNull);
    });

    test('a cancelled appointment records when', () {
      final appointment = Appointment.fromJson(
        realAppointmentCancelled()['data'] as Map<String, dynamic>,
      );
      expect(appointment.status, BookingStatus.cancelled);
      expect(appointment.cancelledAt, isNotNull);
      expect(appointment.canCancel, isFalse);
    });

    test('only pending can be cancelled', () {
      for (final status in BookingStatus.values) {
        expect(
          makeAppointment(status: status).canCancel,
          status == BookingStatus.pending,
          reason: status.label,
        );
      }
    });

    test('an unknown status fails loudly', () {
      final json = Map<String, dynamic>.of(
        realAppointmentCancelled()['data'] as Map<String, dynamic>,
      )..['status'] = 'TELEPORTED';
      expect(() => Appointment.fromJson(json), throwsFormatException);
    });
  });

  group('availability', () {
    test('asks for the day without sending the token', () async {
      adapter.reply(200, realAvailability());
      final result = await repository.availability('svc 1', '2030-05-06');
      expect(adapter.lastRequest.path, '/services/svc%201/availability');
      expect(adapter.lastRequest.queryParameters, {'date': '2030-05-06'});
      expect(adapter.lastRequest.headers.containsKey('Authorization'), isFalse);
      expect(result.slots, isNotEmpty);
    });

    test('a date outside the window is a validation failure', () async {
      adapter.reply(422, {
        'success': false,
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Validation failed',
          'details': [
            {'field': 'query.date', 'message': 'date must be between a and b'},
          ],
        },
      });
      expect(
        await failureOf(repository.availability('s', '2000-01-01')),
        isA<ValidationFailure>(),
      );
    });
  });

  group('create', () {
    test('posts the slot instant and a trimmed note with the token', () async {
      adapter.reply(201, realAppointmentCreated());
      final created = await repository.create(
        serviceId: 'svc-1',
        startsAt: '2030-05-06T10:00:00.000Z',
        note: '  hello  ',
      );
      final request = adapter.lastRequest;
      expect(request.method, 'POST');
      expect(request.path, '/appointments');
      expect(request.data, {
        'serviceId': 'svc-1',
        'startsAt': '2030-05-06T10:00:00.000Z',
        'note': 'hello',
      });
      expect(request.headers['Authorization'], 'Bearer some-token');
      expect(created.status, BookingStatus.pending);
    });

    test('leaves out a blank note', () async {
      adapter.reply(201, realAppointmentCreated());
      await repository.create(
        serviceId: 'svc-1',
        startsAt: '2030-05-06T10:00:00.000Z',
        note: '   ',
      );
      expect((adapter.lastRequest.data as Map).containsKey('note'), isFalse);
    });

    test('a taken slot is a conflict with code SLOT_UNAVAILABLE', () async {
      adapter.reply(409, fixture('error_slot_unavailable.json'));
      final failure = await failureOf(
        repository.create(serviceId: 's', startsAt: '2030-05-06T10:00:00.000Z'),
      );
      expect(failure, isA<ConflictFailure>());
      expect(failure.code, 'SLOT_UNAVAILABLE');
    });
  });

  group('list', () {
    test('sends the scope and parses items and meta', () async {
      adapter.reply(200, realAppointmentsPage());
      final page = await repository.list(scope: AppointmentScope.previous);
      expect(adapter.lastRequest.queryParameters, {
        'scope': 'previous',
        'page': 1,
        'limit': 50,
      });
      expect(page.items, isNotEmpty);
      expect(page.meta.total, page.items.length);
      expect(
        page.items.map((a) => a.status),
        containsAll([BookingStatus.pending, BookingStatus.cancelled]),
      );
    });

    test('a payload without meta is an unknown failure, not a crash', () async {
      adapter.reply(200, {'success': true, 'data': []});
      expect(
        await failureOf(repository.list(scope: AppointmentScope.upcoming)),
        isA<UnknownFailure>(),
      );
    });

    test('a malformed item is an unknown failure', () async {
      adapter.reply(200, {
        'success': true,
        'data': [
          {'id': 1},
        ],
        'meta': {'page': 1, 'limit': 50, 'total': 1},
      });
      expect(
        await failureOf(repository.list(scope: AppointmentScope.upcoming)),
        isA<UnknownFailure>(),
      );
    });
  });

  group('get and cancel', () {
    test('get reads one appointment', () async {
      adapter.reply(200, realAppointmentCreated());
      final appointment = await repository.get('abc');
      expect(adapter.lastRequest.path, '/appointments/abc');
      expect(appointment.service.name, 'Swedish Massage');
    });

    test('get of someone else\'s id is a not-found failure', () async {
      adapter.reply(404, {
        'success': false,
        'error': {'code': 'NOT_FOUND', 'message': 'Appointment not found'},
      });
      expect(await failureOf(repository.get('x')), isA<NotFoundFailure>());
    });

    test('cancel patches and returns the cancelled booking', () async {
      adapter.reply(200, realAppointmentCancelled());
      final cancelled = await repository.cancel('abc');
      expect(adapter.lastRequest.method, 'PATCH');
      expect(adapter.lastRequest.path, '/appointments/abc/cancel');
      expect(cancelled.status, BookingStatus.cancelled);
    });

    test(
      'cancelling a non-pending booking is INVALID_STATUS_TRANSITION',
      () async {
        adapter.reply(409, fixture('error_invalid_transition.json'));
        final failure = await failureOf(repository.cancel('abc'));
        expect(failure, isA<ConflictFailure>());
        expect(failure.code, 'INVALID_STATUS_TRANSITION');
      },
    );

    test('a dropped connection is a network failure', () async {
      adapter.fail(
        (o) => DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(await failureOf(repository.cancel('abc')), isA<NetworkFailure>());
    });
  });
}
