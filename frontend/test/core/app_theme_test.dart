import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/theme/app_theme.dart';

void main() {
  testWidgets('theme builds and applies the key tokens', (tester) async {
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    // Colour scheme is derived from the brand seed.
    expect(theme.useMaterial3, isTrue);
    expect(
      theme.colorScheme.primary,
      ColorScheme.fromSeed(seedColor: AppColors.seed).primary,
    );
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.error, AppColors.error);

    // Buttons meet the minimum touch target.
    final filled = theme.filledButtonTheme.style!;
    expect(
      filled.minimumSize!.resolve({}),
      const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
    );

    // Inputs and cards use the shared radius token.
    final border = theme.inputDecorationTheme.border! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(AppRadius.md));
    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(cardShape.borderRadius, BorderRadius.circular(AppRadius.md));
  });

  test('status palette gives each status a distinct, readable colour pair', () {
    final all = [
      BookingStatusPalette.pending,
      BookingStatusPalette.confirmed,
      BookingStatusPalette.cancelled,
      BookingStatusPalette.completed,
    ];
    expect(all.map((c) => c.background).toSet(), hasLength(4));
    for (final colors in all) {
      final ratio = _contrast(colors.foreground, colors.background);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
