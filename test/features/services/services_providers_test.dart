import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/features/services/data/services_repository.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/domain/service_page.dart';
import 'package:servora/features/services/presentation/services_providers.dart';

import '../../support/fake_services_repository.dart';
import '../../support/service_fixtures.dart';

const debounce = Duration(milliseconds: 40);
const afterDebounce = Duration(milliseconds: 90);

List<Service> catalogue() => [
  makeService(
    id: 'a',
    name: 'Alpha Massage',
    category: 'Wellness',
    isFeatured: true,
  ),
  makeService(id: 'b', name: 'Bravo Haircut', category: 'Beauty'),
  makeService(
    id: 'c',
    name: 'Charlie Cleaning',
    category: 'Home',
    isFeatured: true,
  ),
  makeService(id: 'd', name: 'Delta Repair', category: 'Tech support'),
];

ProviderContainer makeContainer(FakeServicesRepository repo) {
  final container = ProviderContainer(
    overrides: [
      servicesRepositoryProvider.overrideWithValue(repo),
      searchDebounceProvider.overrideWithValue(debounce),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('ServiceFilterNotifier', () {
    test('starts with no search and no category', () {
      final container = makeContainer(FakeServicesRepository(catalogue()));
      expect(container.read(serviceFilterProvider).isEmpty, isTrue);
    });

    test('submitQuery applies at once, trimmed', () {
      final container = makeContainer(FakeServicesRepository(catalogue()));
      container.read(serviceFilterProvider.notifier).submitQuery('  yoga ');
      expect(container.read(serviceFilterProvider).query, 'yoga');
    });

    test('setCategory applies at once, and null clears it', () {
      final container = makeContainer(FakeServicesRepository(catalogue()));
      final notifier = container.read(serviceFilterProvider.notifier);
      notifier.setCategory('Home');
      expect(container.read(serviceFilterProvider).category, 'Home');
      notifier.setCategory(null);
      expect(container.read(serviceFilterProvider).category, isNull);
    });

    test('clear removes both the search and the category', () {
      final container = makeContainer(FakeServicesRepository(catalogue()));
      final notifier = container.read(serviceFilterProvider.notifier);
      notifier
        ..submitQuery('x')
        ..setCategory('Home');
      notifier.clear();
      expect(container.read(serviceFilterProvider).isEmpty, isTrue);
    });

    group('debounce', () {
      test('a keystroke is not applied until typing pauses', () async {
        final container = makeContainer(FakeServicesRepository(catalogue()));
        container.listen(serviceFilterProvider, (_, _) {});
        container.read(serviceFilterProvider.notifier).queryChanged('m');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(container.read(serviceFilterProvider).query, isEmpty);

        await Future<void>.delayed(afterDebounce);
        expect(container.read(serviceFilterProvider).query, 'm');
      });

      test('fast typing applies only the final text, once', () async {
        final container = makeContainer(FakeServicesRepository(catalogue()));
        final applied = <String>[];
        container.listen(
          serviceFilterProvider,
          (_, next) => applied.add(next.query),
        );
        final notifier = container.read(serviceFilterProvider.notifier);

        for (final text in ['m', 'ma', 'mas', 'mass']) {
          notifier.queryChanged(text);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await Future<void>.delayed(afterDebounce);

        expect(applied, ['mass']);
      });

      test('each keystroke restarts the wait', () async {
        final container = makeContainer(FakeServicesRepository(catalogue()));
        container.listen(serviceFilterProvider, (_, _) {});
        final notifier = container.read(serviceFilterProvider.notifier);

        notifier.queryChanged('a');
        await Future<void>.delayed(const Duration(milliseconds: 25));
        notifier.queryChanged('ab'); // restarts the 40 ms window
        await Future<void>.delayed(const Duration(milliseconds: 25));
        // 50 ms after the first key, but only 25 ms after the second.
        expect(container.read(serviceFilterProvider).query, isEmpty);

        await Future<void>.delayed(afterDebounce);
        expect(container.read(serviceFilterProvider).query, 'ab');
      });

      test(
        'typing then deleting back to the applied text sends nothing',
        () async {
          final container = makeContainer(FakeServicesRepository(catalogue()));
          final applied = <String>[];
          container.listen(
            serviceFilterProvider,
            (_, next) => applied.add(next.query),
          );
          final notifier = container.read(serviceFilterProvider.notifier);

          notifier.queryChanged('x');
          notifier.queryChanged(''); // back to the applied (empty) text
          await Future<void>.delayed(afterDebounce);

          expect(applied, isEmpty);
        },
      );

      test('submitQuery cancels a pending debounced search', () async {
        final container = makeContainer(FakeServicesRepository(catalogue()));
        final applied = <String>[];
        container.listen(
          serviceFilterProvider,
          (_, next) => applied.add(next.query),
        );
        final notifier = container.read(serviceFilterProvider.notifier);

        notifier.queryChanged('slow');
        notifier.submitQuery('fast');
        await Future<void>.delayed(afterDebounce);

        expect(applied, ['fast']);
      });

      test('clear cancels a pending search', () async {
        final container = makeContainer(FakeServicesRepository(catalogue()));
        container.listen(serviceFilterProvider, (_, _) {});
        final notifier = container.read(serviceFilterProvider.notifier);

        notifier.queryChanged('pending');
        notifier.clear();
        await Future<void>.delayed(afterDebounce);

        expect(container.read(serviceFilterProvider).isEmpty, isTrue);
      });

      test(
        'disposing the container cancels a pending search without errors',
        () async {
          final repo = FakeServicesRepository(catalogue());
          final container = ProviderContainer(
            overrides: [
              servicesRepositoryProvider.overrideWithValue(repo),
              searchDebounceProvider.overrideWithValue(debounce),
            ],
          );
          container.read(serviceFilterProvider.notifier).queryChanged('late');
          container.dispose();
          await Future<void>.delayed(
            afterDebounce,
          ); // would throw if the timer fired
        },
      );
    });
  });

  group('serviceListProvider', () {
    test('loads the first page for the empty filter', () async {
      final repo = FakeServicesRepository(catalogue());
      final container = makeContainer(repo);

      final state = await container.read(serviceListProvider.future);

      expect(state.items.map((s) => s.id), ['a', 'b', 'c', 'd']);
      expect(state.total, 4);
      expect(state.hasMore, isFalse);
      expect(repo.listRequests.single.filter.isEmpty, isTrue);
      expect(repo.listRequests.single.page, 1);
      expect(repo.listRequests.single.limit, ServiceListNotifier.pageSize);
    });

    test('reloads with the new filter when the filter changes', () async {
      final repo = FakeServicesRepository(catalogue());
      final container = makeContainer(repo);
      container.listen(serviceListProvider, (_, _) {});
      await container.read(serviceListProvider.future);

      container.read(serviceFilterProvider.notifier).submitQuery('haircut');
      final state = await container.read(serviceListProvider.future);

      expect(state.items.map((s) => s.id), ['b']);
      expect(repo.listRequests.last.filter.query, 'haircut');
    });

    test('a category narrows the list too', () async {
      final repo = FakeServicesRepository(catalogue());
      final container = makeContainer(repo);
      container.listen(serviceListProvider, (_, _) {});
      container.read(serviceFilterProvider.notifier).setCategory('Home');
      final state = await container.read(serviceListProvider.future);
      expect(state.items.map((s) => s.id), ['c']);
    });

    test(
      'keeps the previous results visible while a new filter loads',
      () async {
        final gate = Completer<ServicePage>();
        final repo = FakeServicesRepository(catalogue());
        final container = makeContainer(repo);
        container.listen(serviceListProvider, (_, _) {});
        await container.read(serviceListProvider.future);

        repo.onList = (_) => gate.future; // the next request will hang
        container.read(serviceFilterProvider.notifier).submitQuery('delta');
        await settle();

        final during = container.read(serviceListProvider);
        expect(during.isLoading, isTrue);
        expect(during.hasValue, isTrue, reason: 'old data must stay on screen');
        expect(during.value!.items.map((s) => s.id), ['a', 'b', 'c', 'd']);

        gate.complete(FakeServicesRepository.pageOf([catalogue()[3]]));
        final after = await container.read(serviceListProvider.future);
        expect(after.items.map((s) => s.id), ['d']);
      },
    );

    test('a slow, stale response never overwrites a newer list', () async {
      final slow = Completer<ServicePage>();
      final repo = FakeServicesRepository(catalogue());
      final container = makeContainer(repo);
      container.listen(serviceListProvider, (_, _) {});
      await container.read(serviceListProvider.future);

      // Search "alpha": its response is held back.
      repo.onList = (call) {
        if (call.filter.query == 'alpha') return slow.future;
        return Future.value(
          FakeServicesRepository.pageOf([catalogue()[1]]), // "bravo" results
        );
      };
      final notifier = container.read(serviceFilterProvider.notifier);
      notifier.submitQuery('alpha');
      await settle();
      // The user changes their mind and searches "bravo", which answers immediately.
      notifier.submitQuery('bravo');
      final newer = await container.read(serviceListProvider.future);
      expect(newer.items.map((s) => s.id), ['b']);

      // Now the old "alpha" response finally arrives.
      slow.complete(FakeServicesRepository.pageOf([catalogue()[0]]));
      await settle();
      await settle();

      expect(
        container.read(serviceListProvider).value!.items.map((s) => s.id),
        ['b'],
        reason: 'the stale "alpha" result must be ignored',
      );
      expect(container.read(serviceFilterProvider).query, 'bravo');
    });

    test('a failed load is an AsyncError carrying the AppFailure', () async {
      final repo = FakeServicesRepository(catalogue())
        ..onList = (_) => Future.error(const NetworkFailure());
      final container = makeContainer(repo);
      container.listen(serviceListProvider, (_, _) {});

      await expectLater(
        container.read(serviceListProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      expect(container.read(serviceListProvider).hasError, isTrue);
    });

    test('a failed load is not silently retried in the background', () async {
      var calls = 0;
      final repo = FakeServicesRepository(catalogue())
        ..onList = (_) {
          calls++;
          return Future.error(const ServerFailure());
        };
      final container = makeContainer(repo);
      container.listen(serviceListProvider, (_, _) {});
      await container
          .read(serviceListProvider.future)
          .catchError(
            (_) => ServiceListState.fromPage(FakeServicesRepository.pageOf([])),
          );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(calls, 1);
    });

    test('invalidating reloads the list (pull to refresh)', () async {
      final repo = FakeServicesRepository(catalogue());
      final container = makeContainer(repo);
      container.listen(serviceListProvider, (_, _) {});
      await container.read(serviceListProvider.future);

      container.invalidate(serviceListProvider);
      await container.read(serviceListProvider.future);

      expect(repo.listRequests, hasLength(2));
    });

    group('loadMore', () {
      List<Service> many(int n) => [
        for (var i = 0; i < n; i++) makeService(id: 'm$i', name: 'Service $i'),
      ];

      test(
        'appends the next page and stops when everything is loaded',
        () async {
          final repo = FakeServicesRepository(many(45));
          final container = makeContainer(repo);
          container.listen(serviceListProvider, (_, _) {});

          var state = await container.read(serviceListProvider.future);
          expect(state.items, hasLength(20));
          expect(state.hasMore, isTrue);

          await container.read(serviceListProvider.notifier).loadMore();
          state = container.read(serviceListProvider).value!;
          expect(state.items, hasLength(40));
          expect(state.page, 2);
          expect(state.hasMore, isTrue);

          await container.read(serviceListProvider.notifier).loadMore();
          state = container.read(serviceListProvider).value!;
          expect(state.items, hasLength(45));
          expect(state.hasMore, isFalse);
          expect(
            state.items.map((s) => s.id).toSet(),
            hasLength(45),
            reason: 'no duplicates',
          );

          final callsBefore = repo.listCalls.length;
          await container.read(serviceListProvider.notifier).loadMore();
          expect(
            repo.listCalls.length,
            callsBefore,
            reason: 'nothing more to fetch',
          );
        },
      );

      test('ignores a second call while a page is already loading', () async {
        final gate = Completer<ServicePage>();
        final repo = FakeServicesRepository(many(45));
        final container = makeContainer(repo);
        container.listen(serviceListProvider, (_, _) {});
        await container.read(serviceListProvider.future);

        repo.onList = (_) => gate.future;
        final notifier = container.read(serviceListProvider.notifier);
        final first = notifier.loadMore();
        await settle();
        expect(
          container.read(serviceListProvider).value!.isLoadingMore,
          isTrue,
        );
        await notifier.loadMore(); // ignored

        gate.complete(
          FakeServicesRepository.pageOf(
            many(45).sublist(20, 40),
            total: 45,
            page: 2,
          ),
        );
        await first;

        expect(repo.listCalls.where((c) => c.page == 2), hasLength(1));
      });

      test(
        'a failure keeps the loaded items and records the failure',
        () async {
          final repo = FakeServicesRepository(many(45));
          final container = makeContainer(repo);
          container.listen(serviceListProvider, (_, _) {});
          await container.read(serviceListProvider.future);

          repo.onList = (_) => Future.error(const NetworkFailure());
          await container.read(serviceListProvider.notifier).loadMore();

          final state = container.read(serviceListProvider).value!;
          expect(state.items, hasLength(20));
          expect(state.isLoadingMore, isFalse);
          expect(state.loadMoreFailure, isA<NetworkFailure>());
        },
      );

      test('a later successful attempt clears the earlier failure', () async {
        final repo = FakeServicesRepository(many(45));
        final container = makeContainer(repo);
        container.listen(serviceListProvider, (_, _) {});
        await container.read(serviceListProvider.future);

        repo.onList = (_) => Future.error(const NetworkFailure());
        await container.read(serviceListProvider.notifier).loadMore();
        repo.onList = null; // recovers
        await container.read(serviceListProvider.notifier).loadMore();

        final state = container.read(serviceListProvider).value!;
        expect(state.items, hasLength(40));
        expect(state.loadMoreFailure, isNull);
      });

      test(
        'a page that arrives after the filter changed is discarded',
        () async {
          final gate = Completer<ServicePage>();
          final repo = FakeServicesRepository(many(45));
          final container = makeContainer(repo);
          container.listen(serviceListProvider, (_, _) {});
          await container.read(serviceListProvider.future);

          repo.onList = (call) {
            if (call.page == 2) return gate.future;
            return Future.value(
              FakeServicesRepository.pageOf([makeService(id: 'only')]),
            );
          };
          final loading = container
              .read(serviceListProvider.notifier)
              .loadMore();
          await settle();
          container.read(serviceFilterProvider.notifier).submitQuery('only');
          final fresh = await container.read(serviceListProvider.future);
          expect(fresh.items.map((s) => s.id), ['only']);

          gate.complete(
            FakeServicesRepository.pageOf(
              many(45).sublist(20, 40),
              total: 45,
              page: 2,
            ),
          );
          await loading;
          await settle();

          expect(
            container.read(serviceListProvider).value!.items.map((s) => s.id),
            ['only'],
            reason: 'page 2 of the old filter must not be appended',
          );
        },
      );
    });
  });

  group('featuredServicesProvider', () {
    test('asks for featured services only', () async {
      final repo = FakeServicesRepository(catalogue());
      final container = makeContainer(repo);
      final featured = await container.read(featuredServicesProvider.future);
      expect(featured.map((s) => s.id), ['a', 'c']);
      expect(repo.listCalls.single.featured, isTrue);
    });

    test('is independent of the list filter', () async {
      final repo = FakeServicesRepository(catalogue());
      final container = makeContainer(repo);
      container.listen(featuredServicesProvider, (_, _) {});
      await container.read(featuredServicesProvider.future);
      container.read(serviceFilterProvider.notifier).submitQuery('bravo');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.listCalls.where((c) => c.featured == true), hasLength(1));
    });

    test('a failing list does not break featured, and the reverse', () async {
      final repo = FakeServicesRepository(catalogue())
        ..onList = (call) => call.featured == true
            ? Future.value(FakeServicesRepository.pageOf([catalogue()[0]]))
            : Future.error(const ServerFailure());
      final container = makeContainer(repo);
      container.listen(serviceListProvider, (_, _) {});
      container.listen(featuredServicesProvider, (_, _) {});

      await expectLater(
        container.read(serviceListProvider.future),
        throwsA(isA<ServerFailure>()),
      );
      expect(
        (await container.read(featuredServicesProvider.future)).single.id,
        'a',
      );
    });
  });

  group('categoriesProvider', () {
    test('lists each category once, sorted', () async {
      final container = makeContainer(FakeServicesRepository(catalogue()));
      expect(await container.read(categoriesProvider.future), [
        'Beauty',
        'Home',
        'Tech support',
        'Wellness',
      ]);
    });

    test('works from the real ten-service payload', () async {
      final container = makeContainer(FakeServicesRepository(realServices()));
      final categories = await container.read(categoriesProvider.future);
      expect(categories, ['Beauty', 'Home', 'Tech support', 'Wellness']);
    });

    test('does not change when the list is filtered', () async {
      final repo = FakeServicesRepository(catalogue());
      final container = makeContainer(repo);
      container.listen(categoriesProvider, (_, _) {});
      container.read(serviceFilterProvider.notifier).setCategory('Home');
      expect((await container.read(categoriesProvider.future)).length, 4);
    });
  });

  group('serviceDetailProvider', () {
    test('loads one service by id', () async {
      final repo = FakeServicesRepository(catalogue());
      final container = makeContainer(repo);
      final service = await container.read(serviceDetailProvider('c').future);
      expect(service.name, 'Charlie Cleaning');
      expect(repo.getCalls, ['c']);
    });

    test('surfaces a not-found failure', () async {
      final repo = FakeServicesRepository(catalogue())
        ..onGet = (_) => Future.error(const NotFoundFailure());
      final container = makeContainer(repo);
      container.listen(serviceDetailProvider('x'), (_, _) {});
      await expectLater(
        container.read(serviceDetailProvider('x').future),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });
}
