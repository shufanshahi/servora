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
import 'package:servora/core/network/page_meta.dart';
import 'package:servora/core/widgets/status_badge.dart';
import 'package:servora/features/booking/domain/appointment.dart';
import 'package:servora/features/booking/presentation/booking_detail_screen.dart';

import '../../support/app_harness.dart';
import '../../support/booking_fixtures.dart';
import '../../support/fake_appointments_repository.dart';

late FakeAppointmentsRepository repo;

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ServoraApp)));

Future<void> pumpBookings(
  WidgetTester tester,
  List<Appointment> appointments, {
  double width = 400,
  double height = 900,
  double textScale = 1,
  FakeAppointmentsRepository? repository,
}) async {
  useScreen(tester, width: width, height: height, textScale: textScale);
  repo = repository ?? FakeAppointmentsRepository(appointments: appointments);
  await tester.pumpWidget(
    servoraApp(status: AuthStatus.authenticated, appointmentsRepository: repo),
  );
  await tester.pumpAndSettle();
  await tester.tap(navTab('My Bookings'));
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String name) async {
  await tester.tap(find.widgetWithText(Tab, name));
  await tester.pumpAndSettle();
}

List<BookingStatus> shownStatuses(WidgetTester tester) => [
  for (final badge in tester.widgetList<StatusBadge>(find.byType(StatusBadge)))
    badge.status,
];

final cancelButton = find.widgetWithText(OutlinedButton, 'Cancel booking');

void main() {
  group('lists', () {
    testWidgets('upcoming shows pending and confirmed with badges', (
      tester,
    ) async {
      await pumpBookings(tester, [
        makeAppointment(id: 'a', serviceName: 'Swedish Massage'),
        makeAppointment(
          id: 'b',
          status: BookingStatus.confirmed,
          serviceName: 'Private Yoga',
          startsAt: DateTime.utc(2030, 5, 7, 12),
        ),
        makeAppointment(
          id: 'c',
          status: BookingStatus.cancelled,
          serviceName: 'Manicure',
        ),
      ]);
      expect(find.text('Swedish Massage'), findsOneWidget);
      expect(find.text('Private Yoga'), findsOneWidget);
      expect(find.text('Manicure'), findsNothing);
      expect(shownStatuses(tester), [
        BookingStatus.pending,
        BookingStatus.confirmed,
      ]);
      expect(
        find.text(
          '${formatDate(DateTime.utc(2030, 5, 6, 10))}, '
          '${formatTime(DateTime.utc(2030, 5, 6, 10))}',
        ),
        findsOneWidget,
      );
      expect(repo.listCalls, contains(AppointmentScope.upcoming));
    });

    testWidgets('previous shows completed and cancelled', (tester) async {
      await pumpBookings(tester, [
        makeAppointment(id: 'a'),
        makeAppointment(
          id: 'b',
          status: BookingStatus.cancelled,
          serviceName: 'Manicure',
        ),
        makeAppointment(
          id: 'c',
          status: BookingStatus.completed,
          serviceName: 'Haircut & Styling',
        ),
      ]);
      await openTab(tester, 'Previous');
      expect(find.text('Manicure'), findsOneWidget);
      expect(find.text('Haircut & Styling'), findsOneWidget);
      expect(find.text('Swedish Massage'), findsNothing);
      expect(shownStatuses(tester), [
        BookingStatus.cancelled,
        BookingStatus.completed,
      ]);
    });

    testWidgets('each status has its own distinct badge style', (tester) async {
      await pumpBookings(tester, [
        makeAppointment(id: 'a'),
        makeAppointment(id: 'b', status: BookingStatus.confirmed),
      ]);
      final labels = {for (final status in BookingStatus.values) status.label};
      expect(labels, hasLength(4));
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
    });

    testWidgets('empty upcoming and previous tabs say so', (tester) async {
      await pumpBookings(tester, []);
      expect(find.text('No upcoming bookings'), findsOneWidget);
      await openTab(tester, 'Previous');
      expect(find.text('No previous bookings'), findsOneWidget);
    });

    testWidgets('a failed load shows the error with a retry that recovers', (
      tester,
    ) async {
      var failing = true;
      repo = FakeAppointmentsRepository(appointments: [makeAppointment()]);
      repo.onList = (scope) async {
        if (failing) throw const NetworkFailure();
        return AppointmentPage(
          items: [makeAppointment()],
          meta: const PageMeta(page: 1, limit: 50, total: 1),
        );
      };
      await pumpBookings(tester, [], repository: repo);
      expect(find.text(const NetworkFailure().userMessage), findsOneWidget);

      failing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Swedish Massage'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads the list', (tester) async {
      await pumpBookings(tester, [makeAppointment()]);
      final before = repo.listCalls
          .where((s) => s == AppointmentScope.upcoming)
          .length;
      repo.appointments.add(
        makeAppointment(id: 'new', serviceName: 'Private Yoga'),
      );
      await tester.fling(
        find.byType(ListView).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(
        repo.listCalls.where((s) => s == AppointmentScope.upcoming).length,
        greaterThan(before),
      );
      expect(find.text('Private Yoga'), findsOneWidget);
    });

    testWidgets('has no overflow at 320 dp with 2x text', (tester) async {
      await pumpBookings(
        tester,
        [
          makeAppointment(),
          makeAppointment(id: 'b', status: BookingStatus.confirmed),
        ],
        width: 320,
        height: 640,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await openTab(tester, 'Previous');
      expect(tester.takeException(), isNull);
    });
  });

  group('detail', () {
    Future<void> openDetail(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    testWidgets('shows service, schedule, price, note and status', (
      tester,
    ) async {
      await pumpBookings(tester, [
        makeAppointment(note: 'Please use unscented oil'),
      ]);
      await openDetail(tester, 'Swedish Massage');

      expect(find.byType(BookingDetailScreen), findsOneWidget);
      expect(find.text('Swedish Massage'), findsOneWidget);
      expect(find.text('Wellness'), findsOneWidget);
      expect(
        find.text(formatDate(DateTime.utc(2030, 5, 6, 10))),
        findsOneWidget,
      );
      expect(
        find.text(
          formatTimeRange(
            DateTime.utc(2030, 5, 6, 10),
            DateTime.utc(2030, 5, 6, 11),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(formatPrice(65)), findsOneWidget);
      expect(find.text('Please use unscented oil'), findsOneWidget);
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
        BookingStatus.pending,
      );
    });

    testWidgets('a direct link loads the booking by id', (tester) async {
      await pumpBookings(tester, [makeAppointment()]);
      unawaited(
        containerOf(tester)
            .read(routerProvider)
            .push(AppRoutes.bookingDetail('apt-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Swedish Massage'), findsOneWidget);
    });

    testWidgets("someone else's booking is a not-found message", (
      tester,
    ) async {
      await pumpBookings(tester, [makeAppointment()]);
      repo.onGet = (_) async => throw const NotFoundFailure();
      unawaited(
        containerOf(tester)
            .read(routerProvider)
            .push(AppRoutes.bookingDetail('other')),
      );
      await tester.pumpAndSettle();
      expect(find.text(const NotFoundFailure().userMessage), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('has no overflow at 320 dp with 3x text', (tester) async {
      await pumpBookings(
        tester,
        [makeAppointment(note: 'A long note ' * 8)],
        width: 320,
        height: 640,
        textScale: 3,
      );
      await openDetail(tester, 'Swedish Massage');
      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -300));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('cancel', () {
    for (final status in BookingStatus.values) {
      testWidgets(
        'a ${status.label} booking '
        '${status == BookingStatus.pending ? 'offers' : 'does not offer'} cancel',
        (tester) async {
          await pumpBookings(tester, [makeAppointment(status: status)]);
          if (status == BookingStatus.cancelled ||
              status == BookingStatus.completed) {
            await openTab(tester, 'Previous');
          }
          await tester.tap(find.text('Swedish Massage'));
          await tester.pumpAndSettle();
          expect(
            cancelButton,
            status == BookingStatus.pending ? findsOneWidget : findsNothing,
          );
        },
      );
    }

    testWidgets('asks first, and keeping the booking changes nothing', (
      tester,
    ) async {
      await pumpBookings(tester, [makeAppointment()]);
      await tester.tap(find.text('Swedish Massage'));
      await tester.pumpAndSettle();
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
      expect(find.text('Cancel this booking?'), findsOneWidget);

      await tester.tap(find.text('Keep booking'));
      await tester.pumpAndSettle();
      expect(repo.cancelCalls, isEmpty);
      expect(cancelButton, findsOneWidget);
    });

    testWidgets(
      'confirming cancels, shows a message, and moves it to Previous',
      (tester) async {
        await pumpBookings(tester, [makeAppointment()]);
        await tester.tap(find.text('Swedish Massage'));
        await tester.pumpAndSettle();
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Cancel booking'));
        await tester.pumpAndSettle();

        expect(repo.cancelCalls, ['apt-1']);
        expect(find.text('Booking cancelled'), findsOneWidget);
        // The detail now shows Cancelled and offers no more cancelling.
        expect(
          tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
          BookingStatus.cancelled,
        );
        expect(cancelButton, findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('No upcoming bookings'), findsOneWidget);
        await openTab(tester, 'Previous');
        expect(find.text('Swedish Massage'), findsOneWidget);
        expect(
          tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
          BookingStatus.cancelled,
        );
      },
    );

    testWidgets('confirmed meanwhile: a clear message and the real status', (
      tester,
    ) async {
      await pumpBookings(tester, [makeAppointment()]);
      await tester.tap(find.text('Swedish Massage'));
      await tester.pumpAndSettle();

      // The server confirmed it while the screen was open.
      final confirmed = makeAppointment(status: BookingStatus.confirmed);
      repo.appointments[0] = confirmed;
      repo.onCancel = (_) async =>
          throw const ConflictFailure(code: 'INVALID_STATUS_TRANSITION');
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel booking'));
      await tester.pumpAndSettle();

      expect(find.textContaining('can no longer be cancelled'), findsOneWidget);
      expect(
        tester.widget<StatusBadge>(find.byType(StatusBadge)).status,
        BookingStatus.confirmed,
      );
      expect(cancelButton, findsNothing);
    });

    testWidgets('another failure is reported and cancel stays available', (
      tester,
    ) async {
      await pumpBookings(tester, [makeAppointment()]);
      repo.onCancel = (_) async => throw const NetworkFailure();
      await tester.tap(find.text('Swedish Massage'));
      await tester.pumpAndSettle();
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel booking'));
      await tester.pumpAndSettle();
      expect(find.text(const NetworkFailure().userMessage), findsOneWidget);
      expect(cancelButton, findsOneWidget);
    });
  });
}
