import 'package:servora/core/domain/booking_status.dart';
import 'package:servora/core/network/page_meta.dart';

/// The short description of a service that comes with an appointment.
class AppointmentService {
  const AppointmentService({
    required this.id,
    required this.name,
    required this.category,
    required this.durationMinutes,
    this.imageUrl,
  });

  factory AppointmentService.fromJson(Map<String, dynamic> json) {
    return AppointmentService(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      durationMinutes: json['durationMinutes'] as int,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  final String id;
  final String name;
  final String category;
  final int durationMinutes;
  final String? imageUrl;
}

/// A booking, as the API returns it.
class Appointment {
  const Appointment({
    required this.id,
    required this.service,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.price,
    required this.createdAt,
    this.note,
    this.cancelledAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      service: AppointmentService.fromJson(
        json['service'] as Map<String, dynamic>,
      ),
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: BookingStatus.fromApi(json['status'] as String),
      // The price that applied when the booking was made (int or double on the wire).
      price: (json['price'] as num).toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      cancelledAt: json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
    );
  }

  final String id;
  final AppointmentService service;

  /// UTC instants.
  final DateTime startsAt;
  final DateTime endsAt;
  final BookingStatus status;
  final double price;
  final String? note;
  final DateTime createdAt;
  final DateTime? cancelledAt;

  /// Only pending bookings can be cancelled.
  bool get canCancel => status == BookingStatus.pending;
}

/// One bookable start time.
class Slot {
  const Slot({
    required this.startsAt,
    required this.endsAt,
    required this.label,
    required this.available,
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    return Slot(
      startsAt: json['startsAt'] as String,
      endsAt: json['endsAt'] as String,
      label: json['label'] as String,
      available: json['available'] as bool,
    );
  }

  /// UTC instant, exactly as the API sent it (sent back unchanged when booking).
  final String startsAt;
  final String endsAt;

  /// Start time in the business time zone, for display (for example `09:30`).
  final String label;
  final bool available;

  @override
  bool operator ==(Object other) =>
      other is Slot &&
      other.startsAt == startsAt &&
      other.endsAt == endsAt &&
      other.label == label &&
      other.available == available;

  @override
  int get hashCode => Object.hash(startsAt, endsAt, label, available);
}

/// The slots of one service on one day.
class Availability {
  const Availability({
    required this.serviceId,
    required this.date,
    required this.timeZone,
    required this.durationMinutes,
    required this.slots,
  });

  factory Availability.fromJson(Map<String, dynamic> json) {
    return Availability(
      serviceId: json['serviceId'] as String,
      date: json['date'] as String,
      timeZone: json['timeZone'] as String,
      durationMinutes: json['durationMinutes'] as int,
      slots: [
        for (final slot in json['slots'] as List<dynamic>)
          Slot.fromJson(slot as Map<String, dynamic>),
      ],
    );
  }

  final String serviceId;
  final String date;

  /// The zone the slot labels are in.
  final String timeZone;
  final int durationMinutes;
  final List<Slot> slots;

  bool get hasAvailableSlot => slots.any((s) => s.available);
}

/// One page of appointments plus the paging details.
class AppointmentPage {
  const AppointmentPage({required this.items, required this.meta});

  final List<Appointment> items;
  final PageMeta meta;
}

/// Which bookings a list shows.
enum AppointmentScope {
  upcoming('upcoming'),
  previous('previous');

  const AppointmentScope(this.apiValue);

  final String apiValue;
}
