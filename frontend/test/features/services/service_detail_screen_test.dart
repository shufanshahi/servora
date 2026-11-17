import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/app.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/router/app_router.dart';
import 'package:servora/core/router/auth_status.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/loading_view.dart';
import 'package:servora/features/booking/presentation/booking_screen.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/presentation/service_detail_screen.dart';
import 'package:servora/features/services/presentation/widgets/service_card.dart';

import '../../support/app_harness.dart';
import '../../support/fake_services_repository.dart';
import '../../support/service_fixtures.dart';
import '../../support/test_images.dart';

late FakeServicesRepository repo;

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ServoraApp)));

List<Service> get all => realServices();
Service get swedish => all.firstWhere((s) => s.name == 'Swedish Massage');
Service get haircut => all.firstWhere((s) => s.name == 'Haircut & Styling');

Future<void> pumpApp(
  WidgetTester tester, {
  FakeServicesRepository? repository,
  double width = 400,
  double height = 900,
  double textScale = 1,
  AuthStatus status = AuthStatus.authenticated,
}) async {
  useScreen(tester, width: width, height: height, textScale: textScale);
  repo = repository ?? FakeServicesRepository(realServices());
  await tester.pumpWidget(servoraApp(status: status, servicesRepository: repo));
  await tester.pumpAndSettle();
}

/// Opens the detail page the way the Home list does: pushed, with the tapped service.
Future<void> openDetail(
  WidgetTester tester,
  Service service, {
  bool withInitial = true,
  bool settle = true,
}) async {
  unawaited(
    containerOf(tester)
        .read(routerProvider)
        .push(
          AppRoutes.serviceDetail(service.id),
          extra: withInitial ? service : null,
        ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Finder get bookButton => find.widgetWithText(FilledButton, 'Book this service');

void main() {
  group('detail screen', () {
    testWidgets('shows the complete information and a Book action', (
      tester,
    ) async {
      await pumpApp(tester);
      await openDetail(tester, swedish);

      expect(find.byType(ServiceDetailScreen), findsOneWidget);
      expect(find.text('Swedish Massage'), findsOneWidget);
      expect(find.text('Wellness'), findsOneWidget); // category
      expect(
        find.text(swedish.description),
        findsOneWidget,
        reason: 'the FULL description',
      );
      expect(find.text(r'$65'), findsOneWidget);
      expect(find.text('1 h'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(bookButton, findsOneWidget);
    });

    testWidgets('shows every detail of every real service correctly', (
      tester,
    ) async {
      await pumpApp(tester);
      for (final s in all) {
        await openDetail(tester, s);
        expect(find.text(s.name), findsOneWidget, reason: s.name);
        expect(find.text(s.description), findsOneWidget, reason: s.name);
        expect(find.text(s.category), findsOneWidget, reason: s.name);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('does not truncate a long description', (tester) async {
      final long = List.filled(
        60,
        'A thorough and caring treatment.',
      ).join(' ');
      final service = makeService(id: 'long', description: long);
      await pumpApp(tester, repository: FakeServicesRepository([service]));
      await openDetail(tester, service);
      await tester.scrollUntilVisible(
        find.text(long),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(long), findsOneWidget);
    });

    testWidgets('the Book button stays visible while the page scrolls', (
      tester,
    ) async {
      final service = makeService(
        id: 'long',
        description: List.filled(80, 'More detail here.').join(' '),
      );
      await pumpApp(
        tester,
        repository: FakeServicesRepository([service]),
        height: 600,
      );
      await openDetail(tester, service);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      expect(bookButton, findsOneWidget);
      expect(tester.getRect(bookButton).bottom, lessThanOrEqualTo(600));
      expect(tester.getRect(bookButton).top, greaterThan(300));
    });

    testWidgets(
      'a picture that fails to load is replaced by a placeholder, not an error',
      (tester) async {
        await pumpApp(tester);
        useScreen(tester, width: 400, height: 900);
        await tester.pumpWidget(
          servoraApp(
            status: AuthStatus.authenticated,
            servicesRepository: repo,
            imageFactory: (_) => const FailingImageProvider(),
          ),
        );
        await tester.pumpAndSettle();
        await openDetail(tester, swedish);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(bookButton, findsOneWidget);
      },
    );

    testWidgets('announces itself clearly to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      await openDetail(tester, swedish);
      expect(find.bySemanticsLabel(RegExp(r'^Price: \$65')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Duration: 1 h')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Book this service')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('success, loading and error states', () {
    testWidgets('with the list item it appears at once, with no spinner', (
      tester,
    ) async {
      await pumpApp(tester);
      final gate = Completer<Service>();
      repo.onGet = (_) => gate.future; // the API has not answered yet

      await openDetail(tester, swedish, settle: false);
      // Nothing is animating (there is no spinner), so the page transition can finish
      // even though the API has not answered.
      await tester.pumpAndSettle();

      expect(find.byType(LoadingView), findsNothing);
      expect(find.text('Swedish Massage'), findsOneWidget);
      expect(bookButton, findsOneWidget);

      gate.complete(swedish);
      await tester.pumpAndSettle();
      expect(find.text('Swedish Massage'), findsOneWidget);
    });

    testWidgets('newer data from the API replaces the list copy', (
      tester,
    ) async {
      await pumpApp(tester);
      repo.onGet = (_) => Future.value(
        Service(
          id: swedish.id,
          name: swedish.name,
          description: 'Freshly updated description.',
          price: 70,
          durationMinutes: 75,
          category: swedish.category,
          imageUrl: swedish.imageUrl,
          isFeatured: swedish.isFeatured,
        ),
      );
      await openDetail(tester, swedish);
      expect(find.text('Freshly updated description.'), findsOneWidget);
      expect(find.text(r'$70'), findsOneWidget);
      expect(find.text('1 h 15 min'), findsOneWidget);
      expect(find.text(r'$65'), findsNothing);
    });

    testWidgets(
      'opened without the list item it shows a loading state, then the service',
      (tester) async {
        await pumpApp(tester);
        final gate = Completer<Service>();
        repo.onGet = (_) => gate.future;

        await openDetail(tester, swedish, withInitial: false, settle: false);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(LoadingView), findsOneWidget);
        expect(find.text('Loading service'), findsOneWidget);
        expect(bookButton, findsNothing, reason: 'nothing to book yet');

        gate.complete(swedish);
        await tester.pumpAndSettle();
        expect(find.byType(LoadingView), findsNothing);
        expect(find.text('Swedish Massage'), findsOneWidget);
        expect(bookButton, findsOneWidget);
      },
    );

    testWidgets('a failed load shows a readable error that can be retried', (
      tester,
    ) async {
      await pumpApp(tester);
      repo.onGet = (_) => Future.error(const NetworkFailure());

      await openDetail(tester, swedish, withInitial: false);

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      expect(bookButton, findsNothing);
      expect(find.textContaining('Exception'), findsNothing);

      repo.onGet = null; // back online
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('Swedish Massage'), findsOneWidget);
      expect(bookButton, findsOneWidget);
    });

    testWidgets(
      'a service that no longer exists shows the error even with a stale copy',
      (tester) async {
        await pumpApp(tester);
        repo.onGet = (_) => Future.error(const NotFoundFailure());

        await openDetail(tester, swedish);

        expect(find.byType(ErrorView), findsOneWidget);
        expect(find.textContaining("couldn't find"), findsOneWidget);
        expect(
          find.text('Try again'),
          findsNothing,
          reason: 'retrying cannot bring it back',
        );
        expect(find.text(swedish.description), findsNothing);
        expect(
          bookButton,
          findsNothing,
          reason: 'must not book a deleted service',
        );
      },
    );

    testWidgets(
      'a temporary failure keeps showing the copy the user already has',
      (tester) async {
        await pumpApp(tester);
        repo.onGet = (_) => Future.error(const ServerFailure());

        await openDetail(tester, swedish);

        expect(find.byType(ErrorView), findsNothing);
        expect(find.text(swedish.description), findsOneWidget);
        expect(bookButton, findsOneWidget);
      },
    );

    testWidgets('the back button returns to the list', (tester) async {
      await pumpApp(tester);
      await openDetail(tester, swedish);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ServiceDetailScreen), findsNothing);
      expect(find.text('Find a service'), findsOneWidget);
    });
  });

  group('opening a service from the Home list', () {
    testWidgets('tapping a card opens that service', (tester) async {
      await pumpApp(tester, height: 3000);
      final card = find.ancestor(
        of: find.text('Facial Treatment'),
        matching: find.byType(ServiceCard),
      );
      await tester.tap(card);
      await tester.pumpAndSettle();

      final facial = all.firstWhere((s) => s.name == 'Facial Treatment');
      expect(find.byType(ServiceDetailScreen), findsOneWidget);
      expect(
        tester
            .widget<ServiceDetailScreen>(find.byType(ServiceDetailScreen))
            .serviceId,
        facial.id,
      );
      expect(find.text(facial.description), findsOneWidget);
      expect(find.text(r'$70'), findsOneWidget);
      expect(
        find.byType(NavigationBar),
        findsNothing,
        reason: 'a full page above the tabs',
      );
    });

    testWidgets('tapping a featured card opens it too', (tester) async {
      await pumpApp(tester, height: 3000);
      await tester.tap(find.byType(FeaturedServiceCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(ServiceDetailScreen), findsOneWidget);
      expect(bookButton, findsOneWidget);
    });

    testWidgets('going back restores the list exactly as it was', (
      tester,
    ) async {
      // The full list on a short screen, so there is a real distance to scroll.
      await pumpApp(tester, height: 700);
      ScrollableState page() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first);

      page().position.jumpTo(400);
      await tester.pump();
      final before = page().position.pixels;
      expect(before, 400, reason: 'the list is long enough to scroll that far');

      final card = find.byType(ServiceCard).first;
      await tester.tap(card, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(ServiceDetailScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(ServiceDetailScreen), findsNothing);
      expect(page().position.pixels, before, reason: 'scroll position kept');
    });

    testWidgets('going back keeps the search text, category and results', (
      tester,
    ) async {
      await pumpApp(tester, height: 900);
      await tester.enterText(find.byType(TextField), 'massage');
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      final shown = find.byType(ServiceCard).evaluate().length;
      expect(shown, greaterThan(0));

      await tester.tap(find.byType(ServiceCard).first);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'massage',
      );
      expect(find.byType(ServiceCard), findsNWidgets(shown));
      expect(find.text('Results'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets(
      'no overflow at 320 dp with 2x text, and Book stays reachable',
      (tester) async {
        await pumpApp(tester, width: 320, height: 640, textScale: 2.0);
        await openDetail(tester, swedish);
        expect(tester.takeException(), isNull);
        expect(bookButton, findsOneWidget);
        for (var i = 0; i < 4; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(tester.getRect(bookButton).right, lessThanOrEqualTo(320));
        await tester.tap(bookButton);
        await tester.pumpAndSettle();
        expect(find.byType(BookingScreen), findsOneWidget);
      },
    );

    testWidgets('no overflow at 320 dp with 3x text', (tester) async {
      await pumpApp(tester, width: 320, height: 640, textScale: 3.0);
      await openDetail(tester, swedish);
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('on a tablet the content stays in a readable column', (
      tester,
    ) async {
      await pumpApp(tester, width: 1280, height: 900);
      await openDetail(tester, swedish);
      final name = tester.getRect(find.text('Swedish Massage'));
      expect(name.width, lessThan(660));
      expect(name.center.dx, closeTo(640, 4), reason: 'centred');
      expect(tester.getRect(bookButton).width, lessThanOrEqualTo(660));
    });

    testWidgets('phone in landscape has no overflow', (tester) async {
      await pumpApp(tester, width: 740, height: 360);
      await openDetail(tester, swedish);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(bookButton, findsOneWidget);
    });
  });

  group('Book', () {
    testWidgets('opens the booking flow for the selected service', (
      tester,
    ) async {
      await pumpApp(tester);
      await openDetail(tester, swedish);
      await tester.tap(bookButton);
      await tester.pumpAndSettle();

      expect(find.byType(BookingScreen), findsOneWidget);
      expect(
        tester.widget<BookingScreen>(find.byType(BookingScreen)).serviceId,
        swedish.id,
      );
      expect(find.text('Swedish Massage'), findsOneWidget);
    });

    testWidgets('carries the right id for a different service too', (
      tester,
    ) async {
      await pumpApp(tester);
      await openDetail(tester, haircut);
      await tester.tap(bookButton);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BookingScreen>(find.byType(BookingScreen)).serviceId,
        haircut.id,
      );
      expect(find.text('Haircut & Styling'), findsOneWidget);
      expect(repo.getCalls, contains(haircut.id));
    });

    testWidgets('Back from booking returns to the service, then to the list', (
      tester,
    ) async {
      await pumpApp(tester);
      await openDetail(tester, swedish);
      await tester.tap(bookButton);
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ServiceDetailScreen), findsOneWidget);
      expect(find.byType(BookingScreen), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Find a service'), findsOneWidget);
    });

    testWidgets(
      'a signed-out user is sent to login instead of the booking page',
      (tester) async {
        await pumpApp(tester, status: AuthStatus.unauthenticated);
        containerOf(tester)
            .read(routerProvider)
            .go(AppRoutes.serviceBook('some-id'));
        await tester.pumpAndSettle();
        expect(find.byType(BookingScreen), findsNothing);
        expect(find.text('Welcome back'), findsOneWidget);
      },
    );
  });
}
