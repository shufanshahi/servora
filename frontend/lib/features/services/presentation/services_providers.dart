import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/features/services/data/services_repository.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/domain/service_filter.dart';
import 'package:servora/features/services/domain/service_page.dart';

/// Failed loads are shown with a "Try again" button, so Riverpod must not silently
/// retry them in the background as well.
Duration? noAutomaticRetry(int retryCount, Object error) => null;

/// How long typing must pause before a search is sent.
final searchDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 350),
);

/// The filter currently applied to the catalogue. It lives here, not in a screen, so
/// the search text and chosen category survive switching tabs.
class ServiceFilterNotifier extends Notifier<ServiceFilter> {
  Timer? _pendingSearch;

  @override
  ServiceFilter build() {
    ref.onDispose(() => _pendingSearch?.cancel());
    return const ServiceFilter();
  }

  /// Call on every keystroke. The search is applied only once typing pauses, so fast
  /// typing sends one request instead of one per letter.
  void queryChanged(String text) {
    _pendingSearch?.cancel();
    final query = text.trim();
    if (query == state.query.trim()) return; // back to what is already applied
    _pendingSearch = Timer(ref.read(searchDebounceProvider), () {
      state = state.withQuery(query);
    });
  }

  /// Apply the search immediately (the keyboard's search button).
  void submitQuery(String text) {
    _pendingSearch?.cancel();
    state = state.withQuery(text.trim());
  }

  void setCategory(String? category) {
    state = state.withCategory(category);
  }

  /// Remove the search and the category.
  void clear() {
    _pendingSearch?.cancel();
    state = const ServiceFilter();
  }
}

final serviceFilterProvider =
    NotifierProvider<ServiceFilterNotifier, ServiceFilter>(
      ServiceFilterNotifier.new,
    );

/// The services loaded so far for the current filter.
class ServiceListState {
  const ServiceListState({
    required this.items,
    required this.total,
    required this.page,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  factory ServiceListState.fromPage(ServicePage page) => ServiceListState(
    items: page.items,
    total: page.meta.total,
    page: page.meta.page,
  );

  final List<Service> items;

  /// How many services match the filter in total, across all pages.
  final int total;

  /// The last page that has been loaded.
  final int page;
  final bool isLoadingMore;

  /// Set when fetching the next page failed (the loaded items stay on screen).
  final AppFailure? loadMoreFailure;

  bool get hasMore => items.length < total;

  ServiceListState copyWith({
    List<Service>? items,
    int? page,
    bool? isLoadingMore,
    AppFailure? loadMoreFailure,
    bool clearFailure = false,
  }) => ServiceListState(
    items: items ?? this.items,
    total: total,
    page: page ?? this.page,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: clearFailure
        ? null
        : (loadMoreFailure ?? this.loadMoreFailure),
  );
}

/// The catalogue list for the current filter, loaded a page at a time.
///
/// It watches the filter, so changing the filter reloads the list. While that happens
/// the previous results stay available (AsyncValue's "reloading" state), so the screen
/// does not flash empty. If an older request finishes after a newer one has started,
/// Riverpod discards the old result, so it can never overwrite the newer list.
class ServiceListNotifier extends AsyncNotifier<ServiceListState> {
  static const pageSize = 20;

  @override
  Future<ServiceListState> build() async {
    final filter = ref.watch(serviceFilterProvider);
    final page = await ref
        .read(servicesRepositoryProvider)
        .list(filter: filter, limit: pageSize);
    return ServiceListState.fromPage(page);
  }

  /// Fetches and appends the next page. Ignored when there is nothing more, or a page is
  /// already being fetched.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    if (state.isLoading) return; // a reload for a new filter is under way

    final filter = ref.read(serviceFilterProvider);
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearFailure: true),
    );

    try {
      final next = await ref
          .read(servicesRepositoryProvider)
          .list(filter: filter, page: current.page + 1, limit: pageSize);
      // The filter changed while this page was loading: it belongs to a list that is
      // no longer shown.
      if (!ref.mounted || ref.read(serviceFilterProvider) != filter) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          page: next.meta.page,
          isLoadingMore: false,
          clearFailure: true,
        ),
      );
    } on AppFailure catch (failure) {
      if (!ref.mounted || ref.read(serviceFilterProvider) != filter) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreFailure: failure),
      );
    }
  }
}

final serviceListProvider =
    AsyncNotifierProvider<ServiceListNotifier, ServiceListState>(
      ServiceListNotifier.new,
      retry: noAutomaticRetry,
    );

/// Featured services for the highlighted section. Separate from the list, so a
/// failure in one never hides the other.
final featuredServicesProvider = FutureProvider<List<Service>>((ref) async {
  final page = await ref
      .read(servicesRepositoryProvider)
      .list(featured: true, limit: 10);
  return page.items;
}, retry: noAutomaticRetry);

/// The categories to offer as filter chips, taken from the catalogue itself. (The API
/// has no categories endpoint; the whole catalogue is small, so one unfiltered page is
/// enough to discover them.)
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final page = await ref.read(servicesRepositoryProvider).list(limit: 50);
  return ({for (final s in page.items) s.category}.toList()..sort());
}, retry: noAutomaticRetry);

/// One service by id, for the detail screen.
final serviceDetailProvider = FutureProvider.family<Service, String>(
  (ref, id) => ref.read(servicesRepositoryProvider).get(id),
  retry: noAutomaticRetry,
);
