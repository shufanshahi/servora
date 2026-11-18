import 'package:servora/core/domain/booking_status.dart';
import 'package:servora/core/network/page_meta.dart';
import 'package:servora/features/booking/data/appointments_repository.dart';
import 'package:servora/features/booking/domain/appointment.dart';

import 'booking_fixtures.dart';

/// A scriptable [AppointmentsRepository] that behaves like a tiny in-memory backend:
/// bookings it creates show up in its lists, cancelling changes their status. Set the
/// `on...` handlers to take full control of a call (hold it open, throw a failure).
class FakeAppointmentsRepository implements AppointmentsRepository {
  FakeAppointmentsRepository({List<Appointment>? appointments})
    : appointments = [...?appointments];

  final List<Appointment> appointments;

  /// Labels (like `10:00`) shown as unavailable, per date.
  final Map<String, Set<String>> unavailableByDate = {};

  Future<Availability> Function(String serviceId, String date)? onAvailability;
  Future<Appointment> Function(String serviceId, String startsAt, String? note)?
  onCreate;
  Future<AppointmentPage> Function(AppointmentScope scope)? onList;
  Future<Appointment> Function(String id)? onGet;
  Future<Appointment> Function(String id)? onCancel;

  final List<({String serviceId, String date})> availabilityCalls = [];
  final List<({String serviceId, String startsAt, String? note})> createCalls =
      [];
  final List<AppointmentScope> listCalls = [];
  final List<String> cancelCalls = [];

  @override
  Future<Availability> availability(String serviceId, String date) {
    availabilityCalls.add((serviceId: serviceId, date: date));
    final handler = onAvailability;
    if (handler != null) return handler(serviceId, date);
    return Future.value(
      makeAvailability(
        serviceId: serviceId,
        date: date,
        unavailable: unavailableByDate[date] ?? const {},
      ),
    );
  }

  @override
  Future<Appointment> create({
    required String serviceId,
    required String startsAt,
    String? note,
  }) {
    createCalls.add((serviceId: serviceId, startsAt: startsAt, note: note));
    final handler = onCreate;
    if (handler != null) return handler(serviceId, startsAt, note);
    final start = DateTime.parse(startsAt);
    final created = makeAppointment(
      id: 'apt-${appointments.length + 1}',
      startsAt: start,
      note: note,
      serviceId: serviceId,
    );
    appointments.add(created);
    return Future.value(created);
  }

  @override
  Future<AppointmentPage> list({
    required AppointmentScope scope,
    int page = 1,
    int limit = 50,
  }) {
    listCalls.add(scope);
    final handler = onList;
    if (handler != null) return handler(scope);
    final active = {BookingStatus.pending, BookingStatus.confirmed};
    final items = appointments
        .where(
          (a) => scope == AppointmentScope.upcoming
              ? active.contains(a.status)
              : !active.contains(a.status),
        )
        .toList();
    return Future.value(
      AppointmentPage(
        items: items,
        meta: PageMeta(page: 1, limit: limit, total: items.length),
      ),
    );
  }

  @override
  Future<Appointment> get(String id) {
    final handler = onGet;
    if (handler != null) return handler(id);
    return Future.value(appointments.firstWhere((a) => a.id == id));
  }

  @override
  Future<Appointment> cancel(String id) {
    cancelCalls.add(id);
    final handler = onCancel;
    if (handler != null) return handler(id);
    final index = appointments.indexWhere((a) => a.id == id);
    final old = appointments[index];
    final cancelled = Appointment(
      id: old.id,
      service: old.service,
      startsAt: old.startsAt,
      endsAt: old.endsAt,
      status: BookingStatus.cancelled,
      price: old.price,
      note: old.note,
      createdAt: old.createdAt,
      cancelledAt: DateTime.utc(2030, 5, 1, 9),
    );
    appointments[index] = cancelled;
    return Future.value(cancelled);
  }
}
