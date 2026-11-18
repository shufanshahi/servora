import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/router/auth_status.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets(
    'bottom navigation items are announced with labels and position',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(servoraApp(status: AuthStatus.authenticated));
      await tester.pumpAndSettle();

      final destinations = find.byType(NavigationDestination);
      expect(destinations, findsNWidgets(4));

      const labels = ['Home', 'My Bookings', 'Assistant', 'Profile'];
      for (var i = 0; i < labels.length; i++) {
        final semantics = tester.getSemantics(destinations.at(i));
        expect(semantics.label, contains(labels[i]), reason: labels[i]);
        // Screen readers also hear "Tab 1 of 4" style position information.
        expect(semantics.label, contains('${i + 1} of 4'), reason: labels[i]);
      }
      handle.dispose();
    },
  );

  testWidgets('the selected tab is marked selected for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(servoraApp(status: AuthStatus.authenticated));
    await tester.pumpAndSettle();

    final home = tester.getSemantics(find.byType(NavigationDestination).at(0));
    final bookings = tester.getSemantics(
      find.byType(NavigationDestination).at(1),
    );
    expect(
      home.flagsCollection.isSelected,
      isNot(bookings.flagsCollection.isSelected),
    );
    handle.dispose();
  });

  testWidgets('every destination exposes a tooltip label', (tester) async {
    await tester.pumpWidget(servoraApp(status: AuthStatus.authenticated));
    await tester.pumpAndSettle();
    // find.byTooltip only sees the framework's legacy Tooltip type, not
    // material_ui's, so match the widget directly.
    for (final label in ['Home', 'My Bookings', 'Assistant', 'Profile']) {
      final match = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == label,
      );
      expect(match, findsOneWidget, reason: label);
    }
  });
}
