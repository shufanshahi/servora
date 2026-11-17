import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/app.dart';
import 'package:servora/core/domain/booking_status.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/router/app_router.dart';
import 'package:servora/core/router/auth_status.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/widgets/status_badge.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/booking/presentation/booking_confirmation_screen.dart';
import 'package:servora/features/booking/presentation/booking_screen.dart';
import 'package:servora/features/booking/presentation/my_bookings_screen.dart';
import 'package:servora/features/services/domain/service.dart';

import '../../support/app_harness.dart';
import '../../support/booking_fixtures.dart';
import '../../support/fake_appointments_repository.dart';
import '../../support/fake_services_repository.dart';
import '../../support/service_fixtures.dart';

late FakeAppointmentsRepository repo;

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ServoraApp)));

Service get swedish =>
    realServices().firstWhere((s) => s.name == 'Swedish Massage');

Future<void> pumpApp(
  WidgetTester tester, {
  FakeAppointmentsRepository? appointments,
  double width = 400,
  double height = 900,
  double textScale = 1,
}) async {
  useScreen(tester, width: width, height: height, textScale: textScale);
  repo = appointments ?? FakeAppointmentsRepository();
  await tester.pumpWidget(
    servoraApp(
      status: AuthStatus.authenticated,
      servicesRepository: FakeServicesRepository(realServices()),
      appointmentsRepository: repo,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openBooking(WidgetTester tester) async {
  unawaited(
    containerOf(tester)
        .read(routerProvider)
        .push(AppRoutes.serviceBook(swedish.id)),
  );
  await tester.pumpAndSettle();
}

Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

/// The one filled button on the booking screen (its label is a spinner while loading).
final confirmButton = find.byType(FilledButton);
final dateButton = find.byIcon(Icons.calendar_today_outlined);
bool isSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(chip(label)).selected;
bool isEnabled(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(chip(label)).onSelected != null;

void main() {
  group('slot selection', () {
    testWidgets('shows the service, today, and a chip per slot', (
      tester,
    ) async {
      await pumpApp(tester);
      await openBooking(tester);

      expect(find.byType(BookingScreen), findsOneWidget);
      expect(find.text('Swedish Massage'), findsOneWidget);
      expect(find.text(formatDate(DateTime(2030, 5, 1))), findsOneWidget);
      for (final label in [
        '09:00',
        '09:30',
        '10:00',
        '10:30',
        '11:00',
        '11:30',
      ]) {
        expect(chip(label), findsOneWidget);
      }
      expect(repo.availabilityCalls.single.date, '2030-05-01');
      expect(find.textContaining('Times are shown in UTC'), findsOneWidget);
    });

    testWidgets('unavailable slots are disabled and cannot be selected', (
      tester,
    ) async {
      repo = FakeAppointmentsRepository()
        ..unavailableByDate['2030-05-01'] = {'10:00', '10:30'};
      await pumpApp(tester, appointments: repo);
      await openBooking(tester);

      expect(isEnabled(tester, '10:00'), isFalse);
      expect(isEnabled(tester, '10:30'), isFalse);
      expect(isEnabled(tester, '09:30'), isTrue);

      await tester.tap(chip('10:00'), warnIfMissed: false);
      await tester.pump();
      expect(isSelected(tester, '10:00'), isFalse);
      // Nothing was chosen, so there is nothing to confirm.
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
      expect(find.text('Summary'), findsNothing);
    });

    testWidgets('choosing a time shows the summary and enables confirm', (
      tester,
    ) async {
      await pumpApp(tester);
      await openBooking(tester);
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

      await tester.tap(chip('10:30'));
      await tester.pump();
      expect(isSelected(tester, '10:30'), isTrue);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text(formatPrice(swedish.price)), findsWidgets);
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

      // Choosing another time moves the selection.
      await tester.tap(chip('09:00'));
      await tester.pump();
      expect(isSelected(tester, '09:00'), isTrue);
      expect(isSelected(tester, '10:30'), isFalse);
    });

    testWidgets('changing the date clears the selection and loads that day', (
      tester,
    ) async {
      await pumpApp(tester);
      await openBooking(tester);
      await tester.tap(chip('10:30'));
      await tester.pump();

      await tester.tap(dateButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('6'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text(formatDate(DateTime(2030, 5, 6))), findsOneWidget);
      expect(repo.availabilityCalls.last.date, '2030-05-06');
      expect(isSelected(tester, '10:30'), isFalse);
      expect(find.text('Summary'), findsNothing);
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
    });

    testWidgets('the date picker only allows the booking window', (
      tester,
    ) async {
      await pumpApp(tester);
      await openBooking(tester);
      await tester.tap(dateButton);
      await tester.pumpAndSettle();

      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(picker.firstDate, DateTime(2030, 5, 1));
      expect(picker.lastDate, DateTime(2030, 5, 31)); // 30 days ahead
    });

    testWidgets('a day with no free times says so', (tester) async {
      repo = FakeAppointmentsRepository()
        ..unavailableByDate['2030-05-01'] = {
          '09:00',
          '09:30',
          '10:00',
          '10:30',
          '11:00',
          '11:30',
        };
      await pumpApp(tester, appointments: repo);
      await openBooking(tester);
      expect(find.textContaining('No times are available'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('a failed availability load shows a retry that recovers', (
      tester,
    ) async {
      repo = FakeAppointmentsRepository();
      var fail = true;
      repo.onAvailability = (serviceId, date) async {
        if (fail) throw const NetworkFailure();
        return makeAvailability(serviceId: serviceId, date: date);
      };
      await pumpApp(tester, appointments: repo);
      await openBooking(tester);
      expect(find.text(const NetworkFailure().userMessage), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(chip('10:00'), findsOneWidget);
    });
  });

  group('submitting', () {
    Future<void> chooseAndConfirm(
      WidgetTester tester, [
      String label = '10:00',
    ]) async {
      await tester.tap(chip(label));
      await tester.pump();
      await tester.tap(confirmButton);
    }

    testWidgets('success goes to the confirmation with the booking details', (
      tester,
    ) async {
      await pumpApp(tester);
      await openBooking(tester);
      await tester.enterText(find.byType(TextField), 'Window seat');
      await chooseAndConfirm(tester);
      await tester.pumpAndSettle();

      expect(find.byType(BookingConfirmationScreen), findsOneWidget);
      expect(find.byType(BookingScreen), findsNothing);
      expect(repo.createCalls.single.startsAt, '2030-05-01T10:00:00.000Z');
      expect(repo.createCalls.single.note, 'Window seat');
      expect(find.text('Swedish Massage'), findsOneWidget);
      expect(
        find.text(formatDate(DateTime.utc(2030, 5, 1, 10))),
        findsOneWidget,
      );
      expect(
        find.text(
          formatTimeRange(
            DateTime.utc(2030, 5, 1, 10),
            DateTime.utc(2030, 5, 1, 11),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(formatPrice(65)), findsOneWidget);
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
        BookingStatus.pending,
      );
    });

    testWidgets('while the request is pending the button shows loading and '
        'repeated taps send one request', (tester) async {
      final gate = Completer<Appointment>();
      repo = FakeAppointmentsRepository()..onCreate = (_, _, _) => gate.future;
      await pumpApp(tester, appointments: repo);
      await openBooking(tester);
      await chooseAndConfirm(tester);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
      // The grid cannot change under the request either.
      expect(isEnabled(tester, '09:00'), isFalse);
      await tester.tap(confirmButton, warnIfMissed: false);
      await tester.tap(confirmButton, warnIfMissed: false);
      await tester.pump();
      expect(repo.createCalls, hasLength(1));

      gate.complete(makeAppointment(startsAt: DateTime.utc(2030, 5, 1, 10)));
      await tester.pumpAndSettle();
      expect(find.byType(BookingConfirmationScreen), findsOneWidget);
    });

    testWidgets('a slot taken meanwhile keeps the user here, with a message, '
        'a cleared choice and fresh availability', (tester) async {
      repo = FakeAppointmentsRepository();
      repo.onCreate = (_, _, _) async {
        // Someone else books it first.
        repo.unavailableByDate['2030-05-01'] = {'10:00'};
        throw const ConflictFailure(code: 'SLOT_UNAVAILABLE');
      };
      await pumpApp(tester, appointments: repo);
      await openBooking(tester);
      await chooseAndConfirm(tester);
      await tester.pumpAndSettle();

      expect(find.byType(BookingScreen), findsOneWidget);
      expect(find.byType(BookingConfirmationScreen), findsNothing);
      expect(find.textContaining('just taken'), findsOneWidget);
      expect(repo.availabilityCalls, hasLength(2)); // re-read
      expect(isEnabled(tester, '10:00'), isFalse); // now shown as taken
      expect(isSelected(tester, '10:00'), isFalse);
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

      // The user can pick another time and succeed.
      repo.onCreate = null;
      await chooseAndConfirm(tester, '10:30');
      await tester.pumpAndSettle();
      expect(find.byType(BookingConfirmationScreen), findsOneWidget);
    });

    testWidgets('another failure is shown and the user can try again', (
      tester,
    ) async {
      repo = FakeAppointmentsRepository()
        ..onCreate = (_, _, _) async => throw const NetworkFailure();
      await pumpApp(tester, appointments: repo);
      await openBooking(tester);
      await chooseAndConfirm(tester);
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().userMessage), findsOneWidget);
      expect(find.byType(BookingScreen), findsOneWidget);
    });
  });

  group('confirmation', () {
    testWidgets('buttons lead to My Bookings and to Home', (tester) async {
      await pumpApp(tester);
      await openBooking(tester);
      await tester.tap(chip('10:00'));
      await tester.pump();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('View my bookings'));
      await tester.pumpAndSettle();
      expect(find.byType(MyBookingsScreen), findsOneWidget);
      // The new booking is already in Upcoming, as Pending.
      expect(find.text('Swedish Massage'), findsOneWidget);
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
        BookingStatus.pending,
      );

      // And again for Home.
      unawaited(
        containerOf(tester)
            .read(routerProvider)
            .push(AppRoutes.bookingConfirmation, extra: makeAppointment()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to home'));
      await tester.pumpAndSettle();
      expect(find.text('Find a service'), findsOneWidget);
    });

    testWidgets('opened without a booking it goes to My Bookings instead', (
      tester,
    ) async {
      await pumpApp(tester);
      containerOf(tester)
          .read(routerProvider)
          .go(AppRoutes.bookingConfirmation);
      await tester.pumpAndSettle();
      expect(find.byType(BookingConfirmationScreen), findsNothing);
      expect(find.byType(MyBookingsScreen), findsOneWidget);
    });

    testWidgets('has no overflow at 320 dp with 2x text', (tester) async {
      await pumpApp(tester, width: 320, height: 640, textScale: 2);
      unawaited(
        containerOf(tester)
            .read(routerProvider)
            .push(AppRoutes.bookingConfirmation, extra: makeAppointment()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('whole journey', () {
    testWidgets('service detail to confirmation', (tester) async {
      await pumpApp(tester);
      unawaited(
        containerOf(tester)
            .read(routerProvider)
            .push(AppRoutes.serviceDetail(swedish.id), extra: swedish),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book this service'));
      await tester.pumpAndSettle();
      expect(find.byType(BookingScreen), findsOneWidget);

      await tester.tap(chip('11:00'));
      await tester.pump();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();
      expect(find.byType(BookingConfirmationScreen), findsOneWidget);

      // There is no back arrow, and the system Back does not return to a booking form
      // for a booking that already exists.
      expect(find.byType(BackButton), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BookingScreen), findsNothing);
      expect(find.text('About this service'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('booking screen has no overflow at 320 dp with 3x text', (
      tester,
    ) async {
      await pumpApp(tester, width: 320, height: 640, textScale: 3);
      await openBooking(tester);
      await tester.scrollUntilVisible(
        chip('10:00'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(chip('10:00'));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('booking screen is a readable column on a tablet', (
      tester,
    ) async {
      await pumpApp(tester, width: 1280, height: 900);
      await openBooking(tester);
      expect(tester.takeException(), isNull);
      final name = tester.getRect(find.text('Swedish Massage'));
      expect(name.left, greaterThan(300));
    });
  });
}
