import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/features/booking/data/appointments_repository.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/booking/presentation/booking_providers.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_appointments_repository.dart';

void main() {
  late FakeAppointmentsRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeAppointmentsRepository();
    container = ProviderContainer(
      overrides: [
        appointmentsRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2030, 5, 1, 8)),
      ],
    );
    addTearDown(container.dispose);
  });

  const serviceId = 'svc-1';
  final provider = bookingControllerProvider(serviceId);
  BookingState state() => container.read(provider);
  BookingController controller() => container.read(provider.notifier);

  Slot slot(String label, {bool available = true}) => Slot(
    startsAt: '2030-05-06T$label:00.000Z',
    endsAt: '2030-05-06T11:00:00.000Z',
    label: label,
    available: available,
  );

  test('starts on today with nothing chosen', () {
    expect(state().date, DateTime(2030, 5, 1));
    expect(state().slot, isNull);
    expect(state().isSubmitting, isFalse);
  });

  test('choosing a date clears the chosen time', () {
    controller().selectSlot(slot('10:00'));
    expect(state().slot, isNotNull);
    controller().selectDate(DateTime(2030, 5, 6, 15, 30));
    expect(state().date, DateTime(2030, 5, 6)); // time of day dropped
    expect(state().slot, isNull);
  });

  test('picking the same date again keeps the chosen time', () {
    controller().selectSlot(slot('10:00'));
    controller().selectDate(DateTime(2030, 5, 1));
    expect(state().slot, isNotNull);
  });

  test('an unavailable slot cannot be selected', () {
    controller().selectSlot(slot('10:00', available: false));
    expect(state().slot, isNull);
  });

  test('submitting with no slot does nothing', () async {
    expect(await controller().submit(), isNull);
    expect(repo.createCalls, isEmpty);
  });

  test('repeated submits send exactly one request', () async {
    final gate = Completer<Appointment>();
    repo.onCreate = (_, _, _) => gate.future;
    controller().selectSlot(slot('10:00'));

    final first = controller().submit();
    final second = controller().submit();
    final third = controller().submit();
    expect(state().isSubmitting, isTrue);
    expect(await second, isNull);
    expect(await third, isNull);

    gate.complete(makeAppointment());
    expect(await first, isNotNull);
    expect(repo.createCalls, hasLength(1));
    expect(state().isSubmitting, isFalse);
  });

  test(
    'sends the slot instant and the note, and returns the booking',
    () async {
      controller().selectSlot(slot('10:00'));
      final appointment = await controller().submit(note: 'Window seat');
      expect(appointment, isNotNull);
      expect(repo.createCalls.single, (
        serviceId: serviceId,
        startsAt: '2030-05-06T10:00:00.000Z',
        note: 'Window seat',
      ));
    },
  );

  test(
    'a taken slot clears the choice, explains, and re-reads availability',
    () async {
      // Keep the availability provider alive and loaded, like the open screen does.
      final query = (serviceId: serviceId, date: '2030-05-01');
      final sub = container.listen(availabilityProvider(query), (_, _) {});
      addTearDown(sub.close);
      await container.read(availabilityProvider(query).future);
      expect(repo.availabilityCalls, hasLength(1));

      repo.onCreate = (_, _, _) async =>
          throw const ConflictFailure(code: 'SLOT_UNAVAILABLE');
      controller().selectSlot(slot('10:00'));
      final result = await controller().submit();

      expect(result, isNull);
      expect(state().slot, isNull);
      expect(state().isSubmitting, isFalse);
      expect(state().message, contains('just taken'));
      await container.read(availabilityProvider(query).future);
      expect(repo.availabilityCalls, hasLength(2));
    },
  );

  test('another failure keeps the choice out and shows its message', () async {
    repo.onCreate = (_, _, _) async => throw const NetworkFailure();
    controller().selectSlot(slot('10:00'));
    expect(await controller().submit(), isNull);
    expect(state().message, const NetworkFailure().userMessage);
    expect(state().isSubmitting, isFalse);
  });

  test('can submit again after a failure', () async {
    var attempts = 0;
    repo.onCreate = (_, _, _) async {
      attempts++;
      if (attempts == 1) throw const NetworkFailure();
      return makeAppointment();
    };
    controller().selectSlot(slot('10:00'));
    expect(await controller().submit(), isNull);
    controller().selectSlot(slot('10:30'));
    expect(await controller().submit(), isNotNull);
    expect(attempts, 2);
  });

  test('a successful booking refreshes both My Bookings lists', () async {
    for (final scope in AppointmentScope.values) {
      container.listen(appointmentsProvider(scope), (_, _) {});
      await container.read(appointmentsProvider(scope).future);
    }
    expect(repo.listCalls, hasLength(2));

    controller().selectSlot(slot('10:00'));
    await controller().submit();
    for (final scope in AppointmentScope.values) {
      await container.read(appointmentsProvider(scope).future);
    }
    expect(repo.listCalls, hasLength(4));
  });

  group('dateKey', () {
    test('pads month and day', () {
      expect(dateKey(DateTime(2030, 5, 6)), '2030-05-06');
      expect(dateKey(DateTime(2030, 12, 31)), '2030-12-31');
    });
  });
}
