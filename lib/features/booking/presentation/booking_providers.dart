import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/features/booking/data/appointments_repository.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/services/presentation/services_providers.dart';

/// How many days ahead a booking can be made. Matches the API's default
/// (`BOOKING_HORIZON_DAYS`); a date outside the real window is refused by the API.
const bookingHorizonDays = 30;

/// The current moment. A provider so tests can fix it.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// `YYYY-MM-DD` for a calendar day.
String dateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

/// Which service and day to ask about.
typedef AvailabilityQuery = ({String serviceId, String date});

final availabilityProvider = FutureProvider.autoDispose
    .family<Availability, AvailabilityQuery>(
      (ref, query) => ref
          .read(appointmentsRepositoryProvider)
          .availability(query.serviceId, query.date),
      retry: noAutomaticRetry,
    );

/// What the user has chosen so far on the booking screen.
class BookingState {
  const BookingState({
    required this.date,
    this.slot,
    this.isSubmitting = false,
    this.message,
  });

  final DateTime date;
  final Slot? slot;
  final bool isSubmitting;

  /// Why the last submit did not go through (for example the time was just taken).
  final String? message;

  BookingState copyWith({
    DateTime? date,
    Slot? slot,
    bool clearSlot = false,
    bool? isSubmitting,
    String? message,
    bool clearMessage = false,
  }) => BookingState(
    date: date ?? this.date,
    slot: clearSlot ? null : (slot ?? this.slot),
    isSubmitting: isSubmitting ?? this.isSubmitting,
    message: clearMessage ? null : (message ?? this.message),
  );
}

/// The state of one booking in progress, for one service. Dropped when the user leaves
/// the booking screen, so the next visit starts fresh.
class BookingController extends Notifier<BookingState> {
  BookingController(this.serviceId);

  final String serviceId;

  /// Set while a request is in flight, so repeated taps send exactly one request even
  /// before the screen has rebuilt.
  bool _inFlight = false;

  @override
  BookingState build() => BookingState(date: dateOnly(ref.read(nowProvider)()));

  AvailabilityQuery get _query =>
      (serviceId: serviceId, date: dateKey(state.date));

  /// Changing the day always clears the chosen time: it belonged to the old day.
  void selectDate(DateTime day) {
    final picked = dateOnly(day);
    if (picked == state.date) return;
    state = BookingState(date: picked);
  }

  void selectSlot(Slot slot) {
    if (!slot.available || state.isSubmitting) return;
    state = state.copyWith(slot: slot, clearMessage: true);
  }

  /// Sends the booking. Returns the new appointment, or null if it was not made (the
  /// reason is in [BookingState.message] and the user stays on the screen).
  Future<Appointment?> submit({String? note}) async {
    final slot = state.slot;
    if (slot == null || _inFlight) return null;
    _inFlight = true;
    state = state.copyWith(isSubmitting: true, clearMessage: true);
    try {
      final appointment = await ref
          .read(appointmentsRepositoryProvider)
          .create(serviceId: serviceId, startsAt: slot.startsAt, note: note);
      if (!ref.mounted) return appointment;
      state = state.copyWith(isSubmitting: false);
      refreshAppointments(ref);
      // This time is now taken, so the grid must show it that way if the user returns.
      ref.invalidate(availabilityProvider(_query));
      return appointment;
    } on AppFailure catch (failure) {
      if (!ref.mounted) return null;
      final taken =
          failure is ConflictFailure && failure.code == 'SLOT_UNAVAILABLE';
      state = state.copyWith(
        isSubmitting: false,
        clearSlot: true,
        message: taken
            ? 'Sorry, that time was just taken. Please choose another time.'
            : failure.userMessage,
      );
      // Either the time is gone or it was refused for a rule the grid knows about
      // (too soon, for example): re-read the grid so it is right again.
      if (taken || failure is ValidationFailure) {
        ref.invalidate(availabilityProvider(_query));
      }
      return null;
    } finally {
      _inFlight = false;
    }
  }
}

final bookingControllerProvider = NotifierProvider.autoDispose
    .family<BookingController, BookingState, String>(BookingController.new);

/// The user's bookings for one tab.
final appointmentsProvider = FutureProvider.autoDispose
    .family<List<Appointment>, AppointmentScope>((ref, scope) async {
      final page = await ref
          .read(appointmentsRepositoryProvider)
          .list(scope: scope);
      return page.items;
    }, retry: noAutomaticRetry);

/// One booking, by id.
final appointmentDetailProvider = FutureProvider.autoDispose
    .family<Appointment, String>(
      (ref, id) => ref.read(appointmentsRepositoryProvider).get(id),
      retry: noAutomaticRetry,
    );

/// Re-reads both My Bookings tabs (after booking or cancelling).
void refreshAppointments(Ref ref) {
  for (final scope in AppointmentScope.values) {
    ref.invalidate(appointmentsProvider(scope));
  }
}

/// Same, for widgets.
void refreshAppointmentsFromWidget(WidgetRef ref) {
  for (final scope in AppointmentScope.values) {
    ref.invalidate(appointmentsProvider(scope));
  }
}

/// What happened when the user tried to cancel.
sealed class CancelOutcome {
  const CancelOutcome();
}

class CancelSucceeded extends CancelOutcome {
  const CancelSucceeded(this.appointment);
  final Appointment appointment;
}

class CancelFailed extends CancelOutcome {
  const CancelFailed(this.message);
  final String message;
}

/// Cancels a booking and refreshes everything that shows it. If the server says it can
/// no longer be cancelled (it was confirmed meanwhile), the views are refreshed too, so
/// they show the real status.
Future<CancelOutcome> cancelAppointment(WidgetRef ref, String id) async {
  try {
    final cancelled = await ref.read(appointmentsRepositoryProvider).cancel(id);
    refreshAppointmentsFromWidget(ref);
    ref.invalidate(appointmentDetailProvider(id));
    return CancelSucceeded(cancelled);
  } on AppFailure catch (failure) {
    refreshAppointmentsFromWidget(ref);
    ref.invalidate(appointmentDetailProvider(id));
    if (failure is ConflictFailure &&
        failure.code == 'INVALID_STATUS_TRANSITION') {
      return const CancelFailed(
        'This booking can no longer be cancelled because it has already '
        'been confirmed.',
      );
    }
    return CancelFailed(failure.userMessage);
  }
}
