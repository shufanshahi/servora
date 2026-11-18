import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/router/auth_status.dart';
import 'package:servora/core/widgets/empty_view.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/domain/service_page.dart';
import 'package:servora/features/services/presentation/widgets/service_card.dart';
import 'package:servora/features/services/presentation/widgets/service_image.dart';

import '../../support/app_harness.dart';
import '../../support/fake_services_repository.dart';
import '../../support/service_fixtures.dart';
import '../../support/test_images.dart';

late FakeServicesRepository repo;

Future<void> openHome(
  WidgetTester tester, {
  FakeServicesRepository? repository,
  ServiceImageProviderFactory? imageFactory,
  double width = 400,
  double height = 3000,
  double textScale = 1,
  bool settle = true,
}) async {
  useScreen(tester, width: width, height: height, textScale: textScale);
  repo = repository ?? FakeServicesRepository(realServices());
  await tester.pumpWidget(
    servoraApp(
      status: AuthStatus.authenticated,
      servicesRepository: repo,
      imageFactory: imageFactory,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Lets the (short, test-only) search debounce elapse and the new results arrive.
Future<void> afterDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 60));
  await tester.pumpAndSettle();
}

Finder cardFor(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(ServiceCard));

Finder get searchField => find.byType(TextField);

/// Taps a category chip, first scrolling the chip row so the chip is on screen.
Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.pump();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

List<Service> get all => realServices();
Iterable<Service> get featured => all.where((s) => s.isFeatured);

/// A catalogue of [n] generated services.
List<Service> many(int n) => [
  for (var i = 0; i < n; i++)
    makeService(id: 'g$i', name: 'Generated ${i.toString().padLeft(2, '0')}'),
];

void main() {
  group('success state', () {
    testWidgets('shows the heading, the search box and the category chips', (
      tester,
    ) async {
      await openHome(tester);
      expect(find.text('Find a service'), findsOneWidget);
      expect(searchField, findsOneWidget);
      expect(find.text('Search services'), findsOneWidget); // the hint
      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
      for (final category in {for (final s in all) s.category}) {
        expect(
          find.widgetWithText(ChoiceChip, category),
          findsOneWidget,
          reason: category,
        );
      }
    });

    testWidgets('highlights the featured services in their own section', (
      tester,
    ) async {
      await openHome(tester);
      expect(find.text('Featured'), findsOneWidget);
      expect(find.byType(FeaturedServiceCard), findsNWidgets(featured.length));
      for (final s in featured) {
        // once in the Featured row and once in the main list
        expect(find.text(s.name), findsNWidgets(2), reason: s.name);
      }
      for (final s in all.where((s) => !s.isFeatured)) {
        expect(find.text(s.name), findsOneWidget, reason: s.name);
      }
    });

    testWidgets(
      'lists every service with name, description snippet, price and duration',
      (tester) async {
        await openHome(tester);
        expect(find.byType(ServiceCard), findsNWidgets(all.length));
        for (final s in all) {
          final card = cardFor(s.name);
          expect(card, findsOneWidget, reason: s.name);
          expect(
            find.descendant(of: card, matching: find.text(s.description)),
            findsOneWidget,
            reason: s.name,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.textContaining(formatPrice(s.price)),
            ),
            findsOneWidget,
            reason: s.name,
          );
          expect(
            find.descendant(
              of: card,
              matching: find.textContaining(formatDuration(s.durationMinutes)),
            ),
            findsOneWidget,
            reason: s.name,
          );
        }
      },
    );

    testWidgets(
      r'shows a specific card correctly (Swedish Massage, $65, 1 h)',
      (tester) async {
        await openHome(tester);
        final card = cardFor('Swedish Massage');
        expect(
          find.descendant(of: card, matching: find.textContaining(r'$65')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.textContaining('1 h')),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows how many services there are', (tester) async {
      await openHome(tester);
      expect(find.text('All services'), findsOneWidget);
      expect(find.text('${all.length} services'), findsOneWidget);
    });

    testWidgets('gives every card a picture box', (tester) async {
      await openHome(tester);
      expect(
        find.byType(ServiceImage),
        findsNWidgets(all.length + featured.length),
      );
      expect(find.byType(Image), findsNWidgets(all.length + featured.length));
    });

    testWidgets(
      'asks the API for the list, the featured row and the categories',
      (tester) async {
        await openHome(tester);
        final list = repo.listRequests.single;
        expect(list.filter.isEmpty, isTrue);
        expect(list.page, 1);
        expect(list.limit, 20);
        expect(repo.listCalls.where((c) => c.featured == true), hasLength(1));
        expect(repo.listCalls.where((c) => c.limit == 50), hasLength(1));
      },
    );

    testWidgets('cards are announced with name, price and duration', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openHome(tester);
      expect(
        find.bySemanticsLabel(RegExp(r'^Swedish Massage, \$65, 1 h')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('pull to refresh', () {
    testWidgets('reloads the list, the featured row and the categories', (
      tester,
    ) async {
      await openHome(tester, height: 800);
      final before = repo.listCalls.length;

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repo.listCalls.length, before + 3);
      expect(
        find.byType(RefreshProgressIndicator),
        findsNothing,
        reason: 'indicator must disappear',
      );
      expect(find.text('Find a service'), findsOneWidget);
    });

    testWidgets('still ends cleanly when the refresh fails', (tester) async {
      await openHome(tester, height: 800);
      repo.onList = (_) => Future.error(const NetworkFailure());

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(RefreshProgressIndicator), findsNothing);
      // Below the Featured row, so it may be just under the fold.
      expect(
        find.textContaining("Can't reach the server", skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  group('search', () {
    testWidgets(
      'updates the list after a short pause, without reloading the screen',
      (tester) async {
        await openHome(tester);
        final callsBefore = repo.listRequests.length;

        await tester.enterText(searchField, 'massage');
        await tester.pump(const Duration(milliseconds: 5));
        expect(
          repo.listRequests.length,
          callsBefore,
          reason: 'nothing is sent while typing',
        );

        await afterDebounce(tester);

        final expected = all.where(
          (s) =>
              s.name.toLowerCase().contains('massage') ||
              s.description.toLowerCase().contains('massage'),
        );
        expect(repo.listRequests.length, callsBefore + 1);
        expect(repo.listRequests.last.filter.query, 'massage');
        expect(find.byType(ServiceCard), findsNWidgets(expected.length));
        for (final s in expected) {
          expect(cardFor(s.name), findsOneWidget, reason: s.name);
        }
        expect(cardFor('Haircut & Styling'), findsNothing);
        // The heading, search box and chips were never rebuilt away.
        expect(find.text('Find a service'), findsOneWidget);
        expect(find.text('Results'), findsOneWidget);
      },
    );

    testWidgets('fast typing sends a single request for the final text', (
      tester,
    ) async {
      await openHome(tester);
      final callsBefore = repo.listRequests.length;
      for (final text in ['y', 'yo', 'yog', 'yoga']) {
        await tester.enterText(searchField, text);
        await tester.pump(const Duration(milliseconds: 5));
      }
      await afterDebounce(tester);

      expect(repo.listRequests.length, callsBefore + 1);
      expect(repo.listRequests.last.filter.query, 'yoga');
      expect(cardFor('Private Yoga Session'), findsOneWidget);
    });

    testWidgets('hides the Featured row while searching and brings it back', (
      tester,
    ) async {
      await openHome(tester);
      expect(find.text('Featured'), findsOneWidget);
      await tester.enterText(searchField, 'yoga');
      await afterDebounce(tester);
      expect(find.text('Featured'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await afterDebounce(tester);
      expect(find.text('Featured'), findsOneWidget);
    });

    testWidgets(
      'keeps the old results on screen, with a progress bar, while loading',
      (tester) async {
        await openHome(tester);
        final gate = Completer<ServicePage>();
        repo.onList = (_) => gate.future;

        await tester.enterText(searchField, 'delta');
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pump();

        expect(
          find.byType(ServiceCard),
          findsNWidgets(all.length),
          reason: 'old list stays',
        );
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.byType(ServiceCardSkeleton), findsNothing);

        gate.complete(FakeServicesRepository.pageOf([all.first]));
        await tester.pumpAndSettle();
        expect(find.byType(ServiceCard), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );

    testWidgets('the clear button empties the box and restores the full list', (
      tester,
    ) async {
      await openHome(tester);
      expect(
        find.byTooltip('Clear search'),
        findsNothing,
        reason: 'no button when empty',
      );

      await tester.enterText(searchField, 'manicure');
      await afterDebounce(tester);
      expect(find.byType(ServiceCard), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(searchField).controller!.text, isEmpty);
      expect(find.byType(ServiceCard), findsNWidgets(all.length));
      expect(find.byTooltip('Clear search'), findsNothing);
    });

    testWidgets('the keyboard search button applies immediately', (
      tester,
    ) async {
      await openHome(tester);
      await tester.enterText(searchField, 'facial');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repo.listRequests.last.filter.query, 'facial');
      expect(cardFor('Facial Treatment'), findsOneWidget);
    });

    testWidgets('is case-insensitive and ignores surrounding spaces', (
      tester,
    ) async {
      await openHome(tester);
      await tester.enterText(searchField, '  YOGA ');
      await afterDebounce(tester);
      expect(repo.listRequests.last.filter.query, 'YOGA');
      expect(cardFor('Private Yoga Session'), findsOneWidget);
    });
  });

  group('category chips', () {
    testWidgets(
      'choosing a category narrows the list, and All brings everything back',
      (tester) async {
        await openHome(tester);
        await tapChip(tester, 'Beauty');

        final beauty = all.where((s) => s.category == 'Beauty');
        expect(find.byType(ServiceCard), findsNWidgets(beauty.length));
        expect(repo.listRequests.last.filter.category, 'Beauty');
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Beauty'))
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
              .selected,
          isFalse,
        );

        await tapChip(tester, 'All');
        expect(find.byType(ServiceCard), findsNWidgets(all.length));
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
              .selected,
          isTrue,
        );
      },
    );

    testWidgets('choosing the active category again clears it', (tester) async {
      await openHome(tester);
      await tapChip(tester, 'Home');
      expect(repo.listRequests.last.filter.category, 'Home');

      await tapChip(tester, 'Home');
      expect(repo.listRequests.last.filter.category, isNull);
      expect(find.byType(ServiceCard), findsNWidgets(all.length));
    });

    testWidgets('a category and a search combine', (tester) async {
      await openHome(tester);
      await tapChip(tester, 'Wellness');
      await tester.enterText(searchField, 'massage');
      await afterDebounce(tester);

      final call = repo.listRequests.last;
      expect(call.filter.category, 'Wellness');
      expect(call.filter.query, 'massage');
      expect(cardFor('Swedish Massage'), findsOneWidget);
      expect(
        cardFor('Manicure'),
        findsNothing,
      ); // matches "massage" but is Beauty
    });
  });

  group('the filter survives switching tabs', () {
    testWidgets('search text, chosen category and results are still there', (
      tester,
    ) async {
      await openHome(tester);
      await tester.enterText(searchField, 'massage');
      await afterDebounce(tester);
      await tapChip(tester, 'Wellness');
      final shown = find.byType(ServiceCard).evaluate().length;

      await tester.tap(navTab('My Bookings'));
      await tester.pumpAndSettle();
      await tester.tap(navTab('Home'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(searchField).controller!.text, 'massage');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Wellness'))
            .selected,
        isTrue,
      );
      expect(find.byType(ServiceCard), findsNWidgets(shown));
    });
  });

  group('loading', () {
    testWidgets(
      'shows card-shaped placeholders, not an empty screen or an error',
      (tester) async {
        final repository = FakeServicesRepository(realServices());
        final never = Completer<ServicePage>();
        repository.onList = (call) {
          if (call.featured == true || call.limit == 50) {
            return Future.value(
              FakeServicesRepository.pageOf(
                realServices(),
                total: 10,
                limit: 50,
              ),
            );
          }
          return never.future;
        };
        await openHome(tester, repository: repository, settle: false);
        await tester.pump();

        expect(find.byType(ServiceCardSkeleton), findsNWidgets(4));
        expect(find.byType(ServiceCard), findsNothing);
        expect(find.byType(EmptyView), findsNothing);
        expect(find.byType(ErrorView), findsNothing);
        expect(
          find.text('Find a service'),
          findsOneWidget,
        ); // the page itself is already usable
        expect(searchField, findsOneWidget);
      },
    );

    testWidgets(
      'placeholders are replaced by the real cards when data arrives',
      (tester) async {
        final repository = FakeServicesRepository(realServices());
        final gate = Completer<ServicePage>();
        repository.onList = (call) {
          if (call.featured != true && call.limit != 50) return gate.future;
          return Future.value(
            FakeServicesRepository.pageOf(realServices(), total: 10, limit: 50),
          );
        };
        await openHome(tester, repository: repository, settle: false);
        await tester.pump();
        expect(find.byType(ServiceCardSkeleton), findsWidgets);

        gate.complete(FakeServicesRepository.pageOf(realServices(), total: 10));
        await tester.pumpAndSettle();
        expect(find.byType(ServiceCardSkeleton), findsNothing);
        expect(find.byType(ServiceCard), findsNWidgets(10));
      },
    );
  });

  group('empty states', () {
    testWidgets('no match: says so and offers to clear the filters', (
      tester,
    ) async {
      await openHome(tester);
      await tester.enterText(searchField, 'zzzzzz');
      await afterDebounce(tester);

      expect(find.text('No services found'), findsOneWidget);
      expect(
        find.text('Try a different search or choose another category.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Clear filters'),
        findsOneWidget,
      );
      expect(find.byType(ServiceCard), findsNothing);
      expect(find.text('0 services'), findsOneWidget);
    });

    testWidgets(
      'Clear filters clears the search box, the category and the empty state',
      (tester) async {
        await openHome(tester);
        await tapChip(tester, 'Home');
        await tester.enterText(searchField, 'zzzzzz');
        await afterDebounce(tester);
        expect(find.text('No services found'), findsOneWidget);

        await tester.tap(find.text('Clear filters'));
        await tester.pumpAndSettle();

        expect(tester.widget<TextField>(searchField).controller!.text, isEmpty);
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
              .selected,
          isTrue,
        );
        expect(find.text('No services found'), findsNothing);
        expect(find.byType(ServiceCard), findsNWidgets(all.length));
      },
    );

    testWidgets('an empty catalogue says so, with nothing to clear', (
      tester,
    ) async {
      await openHome(tester, repository: FakeServicesRepository([]));
      expect(find.text('No services yet'), findsOneWidget);
      expect(find.text('Clear filters'), findsNothing);
      expect(find.text('Featured'), findsNothing);
    });

    testWidgets('a category with no services shows the filtered empty state', (
      tester,
    ) async {
      // Only Beauty exists in this catalogue, yet "Home" is chosen via a failed lookup.
      final repository = FakeServicesRepository([
        makeService(category: 'Beauty'),
      ]);
      await openHome(tester, repository: repository);
      repository.onList = (call) =>
          Future.value(FakeServicesRepository.pageOf(const []));
      await tester.enterText(searchField, 'nothing');
      await afterDebounce(tester);
      expect(find.text('No services found'), findsOneWidget);
    });
  });

  group('error states', () {
    testWidgets(
      'a failed load shows a readable message and a retry that recovers',
      (tester) async {
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
        await openHome(tester, repository: repository);

        expect(find.byType(ErrorView), findsOneWidget);
        expect(find.textContaining("Can't reach the server"), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.byType(ServiceCard), findsNothing);
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('NetworkFailure'), findsNothing);

        repository.onList = null; // the network is back
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorView), findsNothing);
        expect(find.byType(ServiceCard), findsNWidgets(10));
      },
    );

    testWidgets('a server error gets the generic message', (tester) async {
      final repository = FakeServicesRepository(realServices())
        ..onList = (call) => call.featured == true || call.limit == 50
            ? Future.value(
                FakeServicesRepository.pageOf(
                  realServices(),
                  total: 10,
                  limit: 50,
                ),
              )
            : Future.error(const ServerFailure());
      await openHome(tester, repository: repository);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a failed list does not hide the Featured row', (tester) async {
      final repository = FakeServicesRepository(realServices())
        ..onList = (call) => call.featured == true
            ? Future.value(
                FakeServicesRepository.pageOf(featured.toList(), limit: 10),
              )
            : Future.error(const NetworkFailure());
      await openHome(tester, repository: repository);
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget);
      expect(find.byType(FeaturedServiceCard), findsNWidgets(featured.length));
    });

    testWidgets(
      'a failed Featured row does not break the list, and shows no error',
      (tester) async {
        final repository = FakeServicesRepository(realServices());
        final working = repository.onList;
        repository.onList = (call) => call.featured == true
            ? Future.error(const ServerFailure())
            : (working?.call(call) ??
                  Future.value(
                    FakeServicesRepository.pageOf(
                      realServices(),
                      total: 10,
                      limit: call.limit,
                    ),
                  ));
        await openHome(tester, repository: repository);
        expect(find.byType(ServiceCard), findsNWidgets(10));
        expect(find.text('Featured'), findsNothing);
        expect(find.byType(ErrorView), findsNothing);
      },
    );

    testWidgets('searching can recover from an error too', (tester) async {
      final repository = FakeServicesRepository(realServices());
      repository.onList = (call) => call.featured == true || call.limit == 50
          ? Future.value(
              FakeServicesRepository.pageOf(
                realServices(),
                total: 10,
                limit: 50,
              ),
            )
          : Future.error(const TimeoutFailure());
      await openHome(tester, repository: repository);
      expect(find.textContaining('too long'), findsOneWidget);

      repository.onList = null;
      await tester.enterText(searchField, 'yoga');
      await afterDebounce(tester);
      expect(find.byType(ErrorView), findsNothing);
      expect(cardFor('Private Yoga Session'), findsOneWidget);
    });
  });

  group('loading more', () {
    testWidgets(
      'scrolling to the end fetches the next page and shows a spinner meanwhile',
      (tester) async {
        final repository = FakeServicesRepository(many(45));
        await openHome(tester, repository: repository, height: 700);
        expect(find.text('45 services'), findsOneWidget);

        final gate = Completer<ServicePage>();
        repository.onList = (call) => call.page == 2
            ? gate.future
            : Future.value(FakeServicesRepository.pageOf(const []));
        for (var i = 0; i < 12; i++) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -1200),
          );
          await tester.pump();
        }
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(repository.listCalls.where((c) => c.page == 2), hasLength(1));

        gate.complete(
          FakeServicesRepository.pageOf(
            many(45).sublist(20, 40),
            total: 45,
            page: 2,
          ),
        );
        repository.onList = null; // page 3 comes from the normal fake
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Keep scrolling: the last page loads too, then there is nothing more to fetch.
        for (var i = 0; i < 20; i++) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -1200),
          );
          await tester.pumpAndSettle();
        }
        expect(
          find.text('Generated 44'),
          findsOneWidget,
          reason: 'the very last service',
        );
        expect(repository.listCalls.where((c) => c.page == 3), hasLength(1));
        expect(repository.listCalls.where((c) => c.page == 4), isEmpty);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'a failed page shows a retry banner and keeps the loaded cards',
      (tester) async {
        final repository = FakeServicesRepository(many(45));
        await openHome(tester, repository: repository, height: 700);
        repository.onList = (call) => call.page == 2
            ? Future.error(const NetworkFailure())
            : Future.value(FakeServicesRepository.pageOf(const []));
        for (var i = 0; i < 12; i++) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -1200),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();

        expect(find.textContaining("Can't reach the server"), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(
          find.text('Generated 19'),
          findsOneWidget,
          reason: 'page 1 stays',
        );

        repository.onList = null;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.textContaining("Can't reach the server"), findsNothing);
      },
    );
  });

  group('images', () {
    Size imageBox(WidgetTester tester) =>
        tester.getSize(find.byType(ServiceImage).first);

    testWidgets(
      'a picture that fails to load is replaced by a placeholder of the same size',
      (tester) async {
        await openHome(tester);
        final loaded = imageBox(tester);

        await openHome(
          tester,
          imageFactory: (_) => const FailingImageProvider(),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);
        expect(imageBox(tester), loaded, reason: 'layout must not shift');
        expect(tester.takeException(), isNull);
        expect(find.byType(ServiceCard), findsNWidgets(10));
      },
    );

    testWidgets(
      'while a picture is still loading the placeholder holds its place',
      (tester) async {
        await openHome(tester);
        final loaded = imageBox(tester);

        await openHome(
          tester,
          imageFactory: (_) => const PendingImageProvider(),
          settle: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byIcon(Icons.spa_outlined), findsWidgets);
        expect(imageBox(tester), loaded);
      },
    );

    testWidgets('a service with no picture gets the placeholder', (
      tester,
    ) async {
      final repository = FakeServicesRepository([
        makeService(name: 'No Picture', imageUrl: null),
      ]);
      await openHome(tester, repository: repository);
      expect(find.byIcon(Icons.spa_outlined), findsWidgets);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'each picture is described for screen readers by its service name',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openHome(tester);
        expect(find.bySemanticsLabel('Swedish Massage'), findsWidgets);
        handle.dispose();
      },
    );

    testWidgets('the placeholder itself is hidden from screen readers', (
      tester,
    ) async {
      await openHome(tester, imageFactory: (_) => const FailingImageProvider());
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ServiceImage).first,
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });
  });
}
