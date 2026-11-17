import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';
import 'package:servora/core/network/page_meta.dart';
import 'package:servora/core/network/providers.dart';
import 'package:servora/features/booking/domain/appointment.dart';

/// Booking endpoints. Throws [AppFailure] for every kind of failure; a taken slot is a
/// [ConflictFailure] with code `SLOT_UNAVAILABLE`, and cancelling a non-pending booking is
/// one with code `INVALID_STATUS_TRANSITION`.
class AppointmentsRepository {
  AppointmentsRepository(this._api);

  final ApiClient _api;

  /// [date] is `YYYY-MM-DD`, a calendar day in the business time zone.
  Future<Availability> availability(String serviceId, String date) async {
    final response = await _api.get(
      '/services/${Uri.encodeComponent(serviceId)}/availability',
      query: {'date': date},
      authenticated: false,
    );
    return _parse(() => Availability.fromJson(_map(response.data)));
  }

  /// [startsAt] is the slot's UTC instant exactly as the API sent it.
  Future<Appointment> create({
    required String serviceId,
    required String startsAt,
    String? note,
  }) async {
    final trimmed = note?.trim();
    final response = await _api.post(
      '/appointments',
      body: {
        'serviceId': serviceId,
        'startsAt': startsAt,
        if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed,
      },
    );
    return _parse(() => Appointment.fromJson(_map(response.data)));
  }

  Future<AppointmentPage> list({
    required AppointmentScope scope,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _api.get(
      '/appointments',
      query: {'scope': scope.apiValue, 'page': page, 'limit': limit},
    );
    return _parse(() {
      final meta = response.meta;
      if (meta == null) throw const FormatException('missing meta');
      return AppointmentPage(
        items: [
          for (final item in response.data as List<dynamic>)
            Appointment.fromJson(item as Map<String, dynamic>),
        ],
        meta: PageMeta(page: meta.page, limit: meta.limit, total: meta.total),
      );
    });
  }

  Future<Appointment> get(String id) async {
    final response = await _api.get('/appointments/${Uri.encodeComponent(id)}');
    return _parse(() => Appointment.fromJson(_map(response.data)));
  }

  Future<Appointment> cancel(String id) async {
    final response = await _api.patch(
      '/appointments/${Uri.encodeComponent(id)}/cancel',
    );
    return _parse(() => Appointment.fromJson(_map(response.data)));
  }

  static Map<String, dynamic> _map(Object? data) =>
      data! as Map<String, dynamic>;

  /// A malformed payload is an [UnknownFailure], never a raw exception.
  static T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on Object {
      throw const UnknownFailure();
    }
  }
}

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>(
  (ref) => AppointmentsRepository(ref.watch(apiClientProvider)),
);
