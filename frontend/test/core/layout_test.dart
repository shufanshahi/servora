import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/auth_status.dart';

import '../support/app_harness.dart';

/// Pumps every tab at the current screen size and fails on any layout exception.
Future<void> visitAllTabs(WidgetTester tester) async {
  await tester.pumpWidget(servoraApp(status: AuthStatus.authenticated));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'Home');
  for (final label in ['My Bookings', 'Assistant', 'Profile', 'Home']) {
    await tester.tap(find.text(label));
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
      final first = tester.getRect(find.text('Placeholder service 1'));
      final second = tester.getRect(find.text('Placeholder service 2'));
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
      final box = tester.getRect(find.text('No bookings yet'));
      // Centered inside the max content column, not stretched across 1280 dp.
      expect(box.width, lessThan(Breakpoints.maxContentWidth));
      expect(box.center.dx, closeTo(640, 2));
    });
  });
}
