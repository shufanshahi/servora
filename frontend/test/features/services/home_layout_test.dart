import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/router/auth_status.dart';
import 'package:servora/features/services/domain/service_page.dart';
import 'package:servora/features/services/presentation/widgets/service_card.dart';

import '../../support/app_harness.dart';
import '../../support/fake_services_repository.dart';
import '../../support/service_fixtures.dart';

Future<void> openHome(
  WidgetTester tester, {
  required double width,
  required double height,
  double textScale = 1,
  FakeServicesRepository? repository,
  bool settle = true,
}) async {
  useScreen(tester, width: width, height: height, textScale: textScale);
  await tester.pumpWidget(
    servoraApp(
      status: AuthStatus.authenticated,
      servicesRepository: repository ?? FakeServicesRepository(realServices()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Scrolls the page from top to bottom, failing on any layout exception on the way.
Future<void> scrollThrough(WidgetTester tester, {int steps = 14}) async {
  expect(tester.takeException(), isNull, reason: 'at the top');
  for (var i = 0; i < steps; i++) {
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -500),
    );
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'after scrolling step $i');
  }
}

/// Scrolls the page until [target] has been built and is on screen.
Future<void> bringIntoView(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

Offset topLeftOfCard(WidgetTester tester, String name) => tester.getTopLeft(
  find.ancestor(of: find.text(name), matching: find.byType(ServiceCard)),
);

// The first three services that are not featured, so each name appears exactly once.
const first = 'Deep Tissue Massage';
const second = 'Facial Treatment';
const third = 'Garden & Lawn Care';

void main() {
  group('columns follow the screen width', () {
    testWidgets('a phone shows one column', (tester) async {
      await openHome(tester, width: 400, height: 3000);
      final a = topLeftOfCard(tester, first);
      final b = topLeftOfCard(tester, second);
      expect(a.dx, b.dx, reason: 'same column');
      expect(b.dy, greaterThan(a.dy), reason: 'stacked');
    });

    testWidgets('a portrait tablet shows two columns', (tester) async {
      await openHome(tester, width: 800, height: 3000);
      final a = topLeftOfCard(tester, first);
      final b = topLeftOfCard(tester, second);
      final c = topLeftOfCard(tester, third);
      expect(a.dy, b.dy, reason: 'first two share a row');
      expect(b.dx, greaterThan(a.dx));
      expect(c.dy, greaterThan(a.dy), reason: 'third starts the next row');
      expect(c.dx, a.dx);
    });

    testWidgets('a wide screen shows three columns', (tester) async {
      await openHome(tester, width: 1280, height: 3000);
      final a = topLeftOfCard(tester, first);
      final b = topLeftOfCard(tester, second);
      final c = topLeftOfCard(tester, third);
      expect(a.dy, b.dy);
      expect(b.dy, c.dy);
      expect(a.dx, lessThan(b.dx));
      expect(b.dx, lessThan(c.dx));
    });

    testWidgets('cards in a row are the same height', (tester) async {
      await openHome(tester, width: 800, height: 3000);
      Size sizeOf(String name) => tester.getSize(
        find.ancestor(of: find.text(name), matching: find.byType(ServiceCard)),
      );
      expect(sizeOf(first).height, sizeOf(second).height);
    });

    testWidgets('no card is wider than its column', (tester) async {
      await openHome(tester, width: 800, height: 3000);
      final cards = tester.widgetList(find.byType(ServiceCard)).length;
      expect(cards, 10);
      for (final element in find.byType(ServiceCard).evaluate()) {
        final box = element.renderObject! as RenderBox;
        expect(box.size.width, lessThanOrEqualTo(800 / 2));
      }
    });
  });

  group('no overflow at 320 dp with enlarged text', () {
    for (final scale in [1.0, 1.5, 2.0, 3.0]) {
      testWidgets('loaded page, text scale $scale', (tester) async {
        await openHome(tester, width: 320, height: 640, textScale: scale);
        await scrollThrough(tester);
      });
    }

    testWidgets(
      'the search box, chips and first card are all reachable at 2x',
      (tester) async {
        await openHome(tester, width: 320, height: 640, textScale: 2.0);
        expect(find.byType(TextField), findsOneWidget);
        expect(
          tester.getRect(find.byType(TextField)).right,
          lessThanOrEqualTo(320),
        );
        // The chip row scrolls sideways, so the last chip can be brought into view.
        final lastChip = find.widgetWithText(ChoiceChip, 'Wellness');
        await tester.ensureVisible(lastChip);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(lastChip).right, lessThanOrEqualTo(320.5));
      },
    );

    testWidgets('the loading placeholders', (tester) async {
      final repository = FakeServicesRepository(realServices());
      final never = Completer<ServicePage>();
      repository.onList = (call) => call.featured == true || call.limit == 50
          ? Future.value(
              FakeServicesRepository.pageOf(
                realServices(),
                total: 10,
                limit: 50,
              ),
            )
          : never.future;
      await openHome(
        tester,
        width: 320,
        height: 640,
        textScale: 2.0,
        repository: repository,
        settle: false,
      );
      await tester.pump();
      for (
        var i = 0;
        i < 6 && find.byType(ServiceCardSkeleton).evaluate().isEmpty;
        i++
      ) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -300),
        );
        await tester.pump();
      }
      expect(find.byType(ServiceCardSkeleton), findsWidgets);
      await scrollThrough(tester, steps: 4);
    });

    testWidgets('the empty state', (tester) async {
      await openHome(tester, width: 320, height: 640, textScale: 2.0);
      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      await bringIntoView(tester, find.text('No services found'));
      expect(find.text('No services found'), findsOneWidget);
      await scrollThrough(tester, steps: 4);
      await tester.scrollUntilVisible(
        find.text('Clear filters'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('the error state', (tester) async {
      final repository = FakeServicesRepository(realServices());
      repository.onList = (call) => call.featured == true || call.limit == 50
          ? Future.value(
              FakeServicesRepository.pageOf(
                realServices(),
                total: 10,
                limit: 50,
              ),
            )
          : Future.error(const NetworkFailure());
      await openHome(
        tester,
        width: 320,
        height: 640,
        textScale: 2.0,
        repository: repository,
      );
      await bringIntoView(
        tester,
        find.textContaining("Can't reach the server"),
      );
      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      await scrollThrough(tester, steps: 4);
      await tester.scrollUntilVisible(
        find.text('Try again'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a service with a very long name and description', (
      tester,
    ) async {
      final repository = FakeServicesRepository([
        makeService(
          id: 'long',
          name: 'An Extraordinarily Long Service Name That Keeps Going And Going For Ages',
          description: List.filled(40, 'very long description').join(' '),
          isFeatured: true,
        ),
      ]);
      await openHome(
        tester,
        width: 320,
        height: 640,
        textScale: 2.0,
        repository: repository,
      );
      await scrollThrough(tester, steps: 4);
    });
  });

  group('other screen shapes', () {
    final shapes = {
      'small phone': (w: 320.0, h: 568.0),
      'phone in landscape': (w: 740.0, h: 360.0),
      'tablet in portrait': (w: 800.0, h: 1100.0),
      'tablet in landscape': (w: 1280.0, h: 800.0),
      'very wide desktop-like window': (w: 1600.0, h: 900.0),
    };
    for (final entry in shapes.entries) {
      testWidgets(
        '${entry.key} (${entry.value.w.toInt()} x ${entry.value.h.toInt()})',
        (tester) async {
          await openHome(tester, width: entry.value.w, height: entry.value.h);
          await scrollThrough(tester);
          expect(find.byType(ServiceCard), findsWidgets);
        },
      );
    }
  });
}
