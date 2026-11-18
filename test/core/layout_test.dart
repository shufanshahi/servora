import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/auth_status.dart';

import '../support/app_harness.dart';

/// Pumps every tab at the current screen size and fails on any layout exception.
Future<void> visitAllTabs(WidgetTester tester) async {
  await tester.pumpWidget(servoraApp(status: AuthStatus.authenticated));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'Home');
  for (final label in ['My Bookings', 'Assistant', 'Profile', 'Home']) {
    await tester.tap(navTab(label));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: label);
  }
}

void main() {
  group('gridColumnsFor', () {
    test('is one column on phones', () {
      expect(gridColumnsFor(320), 1);
      expect(gridColumnsFor(360), 1);
      expect(gridColumnsFor(411), 1);
    });

    test('adds columns as the width grows', () {
      expect(gridColumnsFor(600), 2);
      expect(gridColumnsFor(900), 3);
      expect(gridColumnsFor(1200), 4);
    });

    test('always returns at least one column', () {
      expect(gridColumnsFor(0), 1);
      expect(gridColumnsFor(-10), 1);
      expect(gridColumnsFor(100), 1);
    });
  });

  group('small screen (320 dp, enlarged text)', () {
    testWidgets('no overflow on any tab at 2x text scale', (tester) async {
      useScreen(tester, width: 320, height: 640, textScale: 2.0);
      await visitAllTabs(tester);
    });

    testWidgets('the sign-in screen fits at 2x text scale', (tester) async {
      useScreen(tester, width: 320, height: 640, textScale: 2.0);
      await tester.pumpWidget(servoraApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.text('Welcome back'));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    });
  });

  group('wide screens', () {
    testWidgets('tablet portrait uses multiple columns, no overflow', (
      tester,
    ) async {
      useScreen(tester, width: 800, height: 1100);
      await visitAllTabs(tester);
      // Two placeholder cards sit side by side on the first row.
      final first = tester.getRect(find.text('Deep Tissue Massage'));
      final second = tester.getRect(find.text('Facial Treatment'));
      expect((first.top - second.top).abs(), lessThan(1));
      expect(second.left, greaterThan(first.right));
    });

    testWidgets('tablet landscape has no overflow', (tester) async {
      useScreen(tester, width: 1280, height: 800);
      await visitAllTabs(tester);
    });

    testWidgets('phone landscape (short height) has no overflow', (
      tester,
    ) async {
      useScreen(tester, width: 740, height: 360);
      await visitAllTabs(tester);
    });

    testWidgets('reading content is width-constrained on a wide screen', (
      tester,
    ) async {
      useScreen(tester, width: 1280, height: 800);
      await tester.pumpWidget(servoraApp(status: AuthStatus.authenticated));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Bookings'));
      await tester.pumpAndSettle();
      final box = tester.getRect(find.text('No upcoming bookings'));
      // Centered inside the max content column, not stretched across 1280 dp.
      expect(box.width, lessThan(Breakpoints.maxContentWidth));
      expect(box.center.dx, closeTo(640, 2));
    });
  });

  sliverGridTests();
}

class _Tile extends StatelessWidget {
  const _Tile(this.index, {this.height});

  final int index;
  final double? height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    color: const Color(0xFFEEEEEE),
    child: Text('tile $index'),
  );
}

Widget _gridHost({
  required int count,
  double? Function(int index)? heightOf,
  double minTileWidth = 320,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverAdaptiveGrid(
              itemCount: count,
              minTileWidth: minTileWidth,
              itemBuilder: (_, i) => _Tile(i, height: heightOf?.call(i) ?? 40),
            ),
          ),
        ],
      ),
    ),
  );
}

void sliverGridTests() {
  group('SliverAdaptiveGrid', () {
    testWidgets('is one column on a phone', (tester) async {
      useScreen(tester, width: 400, height: 900);
      await tester.pumpWidget(_gridHost(count: 4));
      final lefts = [
        for (var i = 0; i < 4; i++) tester.getTopLeft(find.text('tile $i')).dx,
      ];
      expect(lefts.toSet(), hasLength(1));
      final tops = [
        for (var i = 0; i < 4; i++) tester.getTopLeft(find.text('tile $i')).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(4));
    });

    testWidgets('adds columns as the screen widens', (tester) async {
      Future<int> columnsAt(double width) async {
        useScreen(tester, width: width, height: 900);
        await tester.pumpWidget(_gridHost(count: 12));
        final firstRowTop = tester.getTopLeft(find.text('tile 0')).dy;
        var columns = 0;
        for (var i = 0; i < 12; i++) {
          if (tester.getTopLeft(find.text('tile $i')).dy == firstRowTop) {
            columns++;
          }
        }
        return columns;
      }

      expect(await columnsAt(400), 1);
      expect(await columnsAt(800), 2);
      expect(await columnsAt(1280), 3);
    });

    testWidgets('builds every item exactly once, including a short last row', (
      tester,
    ) async {
      useScreen(tester, width: 800, height: 900);
      await tester.pumpWidget(_gridHost(count: 5)); // 2 columns: 2 + 2 + 1
      for (var i = 0; i < 5; i++) {
        expect(find.text('tile $i'), findsOneWidget);
      }
      expect(find.text('tile 5'), findsNothing);
    });

    testWidgets('tiles in a row share the height of the tallest', (
      tester,
    ) async {
      useScreen(tester, width: 800, height: 900);
      await tester.pumpWidget(
        _gridHost(count: 2, heightOf: (i) => i == 0 ? 40 : 120),
      );
      final heights = [
        for (var i = 0; i < 2; i++)
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text('tile $i'),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .height,
      ];
      expect(heights[0], heights[1]);
      expect(heights[0], 120);
    });

    testWidgets('tile heights may differ between rows', (tester) async {
      useScreen(tester, width: 400, height: 900);
      await tester.pumpWidget(
        _gridHost(count: 2, heightOf: (i) => i == 0 ? 40 : 200),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('tile 1'), findsOneWidget);
    });

    testWidgets(
      'a lone tile in the last row is not stretched across the screen',
      (tester) async {
        useScreen(tester, width: 800, height: 900);
        await tester.pumpWidget(_gridHost(count: 3));
        final full = tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('tile 0'),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .width;
        final lone = tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('tile 2'),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .width;
        expect(lone, full);
      },
    );

    testWidgets('an empty grid builds nothing and does not throw', (
      tester,
    ) async {
      useScreen(tester, width: 400, height: 900);
      await tester.pumpWidget(_gridHost(count: 0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('large lists are built lazily', (tester) async {
      useScreen(tester, width: 400, height: 600);
      await tester.pumpWidget(_gridHost(count: 500));
      expect(find.text('tile 0'), findsOneWidget);
      expect(find.text('tile 400'), findsNothing);
    });
  });
}
