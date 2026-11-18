import 'dart:convert';
import 'dart:io';

import 'package:servora/core/domain/booking_status.dart';
import 'package:servora/features/booking/domain/appointment.dart';

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

/// Real API payloads (captured from the running backend).
Map<String, dynamic> realAvailability() => _json('availability.json');
Map<String, dynamic> realAppointmentCreated() =>
    _json('appointment_created.json');
Map<String, dynamic> realAppointmentCancelled() =>
    _json('appointment_cancelled.json');
Map<String, dynamic> realAppointmentsPage() => _json('appointments_page.json');

const swedishServiceJson = {
  'id': 'svc-swedish',
  'name': 'Swedish Massage',
  'category': 'Wellness',
  'durationMinutes': 60,
  'imageUrl': null,
};

/// A hand-made appointment on 6 May 2030, 10:00-11:00 UTC.
Appointment makeAppointment({
  String id = 'apt-1',
  BookingStatus status = BookingStatus.pending,
  DateTime? startsAt,
  double price = 65,
  String? note,
  String serviceName = 'Swedish Massage',
  String serviceId = 'svc-swedish',
}) {
  final start = startsAt ?? DateTime.utc(2030, 5, 6, 10);
  return Appointment(
    id: id,
    service: AppointmentService(
      id: serviceId,
      name: serviceName,
      category: 'Wellness',
      durationMinutes: 60,
    ),
    startsAt: start,
    endsAt: start.add(const Duration(hours: 1)),
    status: status,
    price: price,
    note: note,
    createdAt: DateTime.utc(2030, 5, 1, 8),
    cancelledAt: status == BookingStatus.cancelled
        ? DateTime.utc(2030, 5, 1, 9)
        : null,
  );
}

/// Slots every 30 minutes from 09:00 for [count] slots; [unavailable] are labels like
/// `10:00` that are shown as taken. Instants are UTC on [date] (business zone = UTC).
Availability makeAvailability({
  required String serviceId,
  required String date,
  Set<String> unavailable = const {},
  int count = 6,
  int durationMinutes = 60,
}) {
  final slots = <Slot>[];
  for (var i = 0; i < count; i++) {
    final minutes = 9 * 60 + i * 30;
    final label =
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
    final start = DateTime.parse('${date}T$label:00Z');
    slots.add(
      Slot(
        startsAt: start.toIso8601String(),
        endsAt: start.add(Duration(minutes: durationMinutes)).toIso8601String(),
        label: label,
        available: !unavailable.contains(label),
      ),
    );
  }
  return Availability(
    serviceId: serviceId,
    date: date,
    timeZone: 'UTC',
    durationMinutes: durationMinutes,
    slots: slots,
  );
}
