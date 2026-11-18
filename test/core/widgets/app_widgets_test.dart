import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/theme/app_theme.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/app_text_field.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppButton', () {
    testWidgets('enabled: shows label and fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton(label: 'Book now', onPressed: () => taps++)),
      );
      expect(find.text('Book now'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
    });

    testWidgets('disabled: has no handler and reports disabled to a11y', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const AppButton(label: 'Save', onPressed: null)),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Save')),
        isSemantics(isButton: true, isEnabled: false, hasEnabledState: true),
      );
      handle.dispose();
    });

    testWidgets('loading: shows spinner, hides label, ignores taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppButton(label: 'Sign in', isLoading: true, onPressed: () => taps++),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('meets the 48 dp minimum target in every variant', (
      tester,
    ) async {
      for (final variant in AppButtonVariant.values) {
        await tester.pumpWidget(
          host(
            AppButton(
              label: 'X',
              variant: variant,
              expand: false,
              onPressed: () {},
            ),
          ),
        );
        final size = tester.getSize(
          find.byWidgetPredicate(
            (w) => w is FilledButton || w is OutlinedButton || w is TextButton,
          ),
        );
        expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
        expect(size.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      }
    });

    testWidgets('exposes a semantic label, including loading state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(AppButton(label: 'Sign in', isLoading: true, onPressed: () {})),
      );
      expect(find.bySemanticsLabel('Sign in, loading'), findsOneWidget);
      handle.dispose();
    });
  });

  group('AppTextField', () {
    testWidgets('renders the label and accepts input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        host(AppTextField(label: 'Email', controller: controller)),
      );
      expect(find.text('Email'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'a@b.test');
      expect(controller.text, 'a@b.test');
    });

    testWidgets('shows externally supplied error text', (tester) async {
      await tester.pumpWidget(
        host(
          const AppTextField(label: 'Email', errorText: 'Email already in use'),
        ),
      );
      expect(find.text('Email already in use'), findsOneWidget);
    });

    testWidgets('shows validator errors inside a Form', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: key,
            child: AppTextField(
              label: 'Name',
              validator: (v) => (v ?? '').isEmpty ? 'Name is required' : null,
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('password field hides text and toggles visibility', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AppTextField(label: 'Password', obscureText: true)),
      );
      EditableText editable() =>
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editable().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(editable().obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('disabled field rejects input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        host(AppTextField(label: 'X', controller: controller, enabled: false)),
      );
      await tester.enterText(find.byType(TextFormField), 'nope');
      expect(controller.text, isEmpty);
    });
  });

  group('AppCard', () {
    testWidgets('renders its child and is not tappable without onTap', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppCard(child: Text('Hello'))));
      expect(find.text('Hello'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('fires onTap and meets the minimum height', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppCard(onTap: () => taps++, child: const Text('Tap'))),
      );
      await tester.tap(find.byType(AppCard));
      expect(taps, 1);
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(AppSpacing.minTouchTarget),
      );
    });
  });
}
