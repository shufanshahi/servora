import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/domain/booking_status.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_theme.dart';
import 'package:servora/core/widgets/status_badge.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

Color badgeBackground(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(StatusBadge),
      matching: find.byType(Container),
    ),
  );
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  const expectedColors = {
    BookingStatus.pending: BookingStatusPalette.pending,
    BookingStatus.confirmed: BookingStatusPalette.confirmed,
    BookingStatus.cancelled: BookingStatusPalette.cancelled,
    BookingStatus.completed: BookingStatusPalette.completed,
  };
  const expectedLabels = {
    BookingStatus.pending: 'Pending',
    BookingStatus.confirmed: 'Confirmed',
    BookingStatus.cancelled: 'Cancelled',
    BookingStatus.completed: 'Completed',
  };

  for (final status in BookingStatus.values) {
    testWidgets('${status.name}: shows its label and colour', (tester) async {
      await tester.pumpWidget(host(StatusBadge(status: status)));
      expect(find.text(expectedLabels[status]!), findsOneWidget);
      expect(badgeBackground(tester), expectedColors[status]!.background);
      final text = tester.widget<Text>(find.text(expectedLabels[status]!));
      expect(text.style!.color, expectedColors[status]!.foreground);
    });
  }

  testWidgets('all four variants are visually distinct', (tester) async {
    final seen = <Color>{};
    final icons = <IconData?>{};
    for (final status in BookingStatus.values) {
      await tester.pumpWidget(host(StatusBadge(status: status)));
      seen.add(badgeBackground(tester));
      icons.add(tester.widget<Icon>(find.byType(Icon)).icon);
    }
    expect(seen, hasLength(4));
    expect(icons, hasLength(4)); // not colour-only
  });

  testWidgets('announces its status to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const StatusBadge(status: BookingStatus.confirmed)),
    );
    expect(find.bySemanticsLabel('Status: Confirmed'), findsOneWidget);
    handle.dispose();
  });

  group('BookingStatus.fromApi', () {
    test('parses every API value', () {
      expect(BookingStatus.fromApi('PENDING'), BookingStatus.pending);
      expect(BookingStatus.fromApi('CONFIRMED'), BookingStatus.confirmed);
      expect(BookingStatus.fromApi('CANCELLED'), BookingStatus.cancelled);
      expect(BookingStatus.fromApi('COMPLETED'), BookingStatus.completed);
    });

    test('rejects unknown values loudly', () {
      expect(() => BookingStatus.fromApi('DONE'), throwsFormatException);
      expect(() => BookingStatus.fromApi('pending'), throwsFormatException);
    });
  });
}
