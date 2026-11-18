import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/theme/app_theme.dart';
import 'package:servora/core/widgets/async_value_view.dart';
import 'package:servora/core/widgets/empty_view.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/loading_view.dart';

import '../../support/app_harness.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('LoadingView', () {
    testWidgets('shows a progress indicator and optional message', (t) async {
      await t.pumpWidget(host(const LoadingView(message: 'Loading services')));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading services'), findsOneWidget);
    });
  });

  group('EmptyView', () {
    testWidgets('shows title and message without an action', (t) async {
      await t.pumpWidget(
        host(const EmptyView(title: 'No bookings', message: 'Book a service')),
      );
      expect(find.text('No bookings'), findsOneWidget);
      expect(find.text('Book a service'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('action button fires its callback', (t) async {
      var taps = 0;
      await t.pumpWidget(
        host(
          EmptyView(
            title: 'No results',
            actionLabel: 'Clear filters',
            onAction: () => taps++,
          ),
        ),
      );
      await t.tap(find.text('Clear filters'));
      expect(taps, 1);
    });
  });

  group('ErrorView', () {
    testWidgets('shows the message and a retry button that fires', (t) async {
      var retries = 0;
      await t.pumpWidget(
        host(ErrorView(message: 'Connection failed', onRetry: () => retries++)),
      );
      expect(find.text('Connection failed'), findsOneWidget);
      await t.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('hides retry when no callback is supplied', (t) async {
      await t.pumpWidget(host(const ErrorView(message: 'Nope')));
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('AsyncValueView', () {
    Widget view(AsyncValue<List<String>> value, {VoidCallback? onRetry}) {
      return host(
        AsyncValueView<List<String>>(
          value: value,
          onRetry: onRetry,
          isEmpty: (items) => items.isEmpty,
          empty: const EmptyView(title: 'Empty list'),
          data: (items) => Text('items: ${items.join(",")}'),
        ),
      );
    }

    testWidgets('loading state', (t) async {
      await t.pumpWidget(view(const AsyncLoading()));
      expect(find.byType(LoadingView), findsOneWidget);
    });

    testWidgets('data state', (t) async {
      await t.pumpWidget(view(const AsyncData(['a', 'b'])));
      expect(find.text('items: a,b'), findsOneWidget);
    });

    testWidgets('empty state', (t) async {
      await t.pumpWidget(view(const AsyncData(<String>[])));
      expect(find.text('Empty list'), findsOneWidget);
    });

    testWidgets('error state shows the friendly message and retries', (
      t,
    ) async {
      var retries = 0;
      await t.pumpWidget(
        view(
          AsyncError(const NetworkFailure(), StackTrace.empty),
          onRetry: () => retries++,
        ),
      );
      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      await t.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('raw exceptions are never shown', (t) async {
      await t.pumpWidget(
        view(AsyncError(StateError('boom internal'), StackTrace.empty)),
      );
      expect(find.textContaining('boom'), findsNothing);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('small viewports', () {
    testWidgets('EmptyView scrolls instead of overflowing', (t) async {
      useScreen(t, width: 320, height: 300, textScale: 2.0);
      await t.pumpWidget(
        host(
          const EmptyView(
            title: 'No bookings yet',
            message: 'Your upcoming and previous bookings will appear here.',
            actionLabel: 'Browse services',
            onAction: _noop,
          ),
        ),
      );
      expect(t.takeException(), isNull);
      // Content is taller than the viewport but reachable by scrolling.
      await t.scrollUntilVisible(
        find.text('Browse services'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Browse services'), findsOneWidget);
    });

    testWidgets('ErrorView scrolls instead of overflowing', (t) async {
      useScreen(t, width: 320, height: 300, textScale: 2.0);
      await t.pumpWidget(
        host(
          const ErrorView(
            message: "Can't reach the server. Check your internet connection.",
            onRetry: _noop,
          ),
        ),
      );
      expect(t.takeException(), isNull);
      await t.scrollUntilVisible(
        find.text('Try again'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}

void _noop() {}
