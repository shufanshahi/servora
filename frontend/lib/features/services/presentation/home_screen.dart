import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/empty_view.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/message_banner.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/presentation/services_providers.dart';
import 'package:servora/features/services/presentation/widgets/category_chips.dart';
import 'package:servora/features/services/presentation/widgets/service_card.dart';
import 'package:servora/features/services/presentation/widgets/service_search_field.dart';

/// The Home tab: search, category chips, a highlighted "Featured" row and the full list.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _skeletonCount = 4;
  static const _loadMoreDistance = 320.0;

  final _scroll = ScrollController();
  late final TextEditingController _search;
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The filter outlives this screen, so start from whatever is applied.
    _search = TextEditingController(
      text: ref.read(serviceFilterProvider).query,
    );
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_maybeLoadMore)
      ..dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < _loadMoreDistance) {
      unawaited(ref.read(serviceListProvider.notifier).loadMore());
    }
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(featuredServicesProvider)
      ..invalidate(categoriesProvider)
      ..invalidate(serviceListProvider);
    try {
      await ref.read(serviceListProvider.future);
    } on Object {
      // The failure is shown by the list itself; the refresh indicator just ends.
    }
  }

  void _clearFilters() {
    _search.clear();
    ref.read(serviceFilterProvider.notifier).clear();
  }

  void _open(Service service) {
    unawaited(
      context.push(AppRoutes.serviceDetail(service.id), extra: service),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Another screen (the assistant) asked for the search box. Wait a frame so this tab
    // is on screen before it takes focus.
    ref.listen<int>(searchFocusRequestProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    });
    final filter = ref.watch(serviceFilterProvider);
    final list = ref.watch(serviceListProvider);
    final theme = Theme.of(context);
    final filterNotifier = ref.read(serviceFilterProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? const <String>[];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find a service', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  ServiceSearchField(
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: filterNotifier.queryChanged,
                    onSubmitted: filterNotifier.submitQuery,
                    onClear: () {
                      _search.clear();
                      filterNotifier.submitQuery('');
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CategoryChips(
                    categories: categories,
                    selected: filter.category,
                    onSelected: filterNotifier.setCategory,
                  ),
                ],
              ),
            ),
          ),
          if (filter.isEmpty) ..._featuredSlivers(theme),
          ..._resultSlivers(theme, filter.isEmpty, list),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],
      ),
    );
  }

  List<Widget> _featuredSlivers(ThemeData theme) {
    final services = ref.watch(featuredServicesProvider).value;
    // Featured is a bonus: nothing is shown while it loads or if it fails.
    if (services == null || services.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Semantics(
            header: true,
            child: Text('Featured', style: theme.textTheme.titleMedium),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final service in services) ...[
                  FeaturedServiceCard(
                    service: service,
                    onTap: () => _open(service),
                  ),
                  if (service != services.last)
                    const SizedBox(width: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// Gives an empty or error message a box of its own inside the scrolling page. The box
  /// grows with the user's text size, and the message scrolls inside it if it must.
  /// (A plain `SliverFillRemaining` would hand these widgets unbounded height.)
  Widget _stateSliver(Widget child) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SliverToBoxAdapter(
      child: SizedBox(height: 320 * scale.clamp(1.0, 2.5), child: child),
    );
  }

  List<Widget> _resultSlivers(
    ThemeData theme,
    bool noFilter,
    AsyncValue<ServiceListState> list,
  ) {
    const padding = EdgeInsets.symmetric(horizontal: AppSpacing.md);

    Widget header(String title, {int? total}) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        // A Wrap, not a Row: with very large text the count drops under the title instead
        // of overflowing the screen.
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: AppSpacing.xs,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            if (total != null)
              Text(
                total == 1 ? '1 service' : '$total services',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
    final title = noFilter ? 'All services' : 'Results';

    // A failed load wins over stale data: say so, with a way to try again.
    if (list.hasError && !list.isLoading) {
      return [
        header(title),
        _stateSliver(
          ErrorView(
            message: userMessageFor(list.error!),
            onRetry: () => ref.invalidate(serviceListProvider),
          ),
        ),
      ];
    }

    final data = list.value;
    if (data == null) {
      // First load: grey placeholders in the shape of the cards.
      return [
        header(title),
        SliverPadding(
          padding: padding,
          sliver: SliverAdaptiveGrid(
            itemCount: _skeletonCount,
            itemBuilder: (_, _) => const ServiceCardSkeleton(),
          ),
        ),
      ];
    }

    if (data.items.isEmpty) {
      return [
        header(title, total: 0),
        _stateSliver(
          noFilter
              ? const EmptyView(
                  title: 'No services yet',
                  message: 'Check back soon: new services are added regularly.',
                  icon: Icons.spa_outlined,
                )
              : EmptyView(
                  title: 'No services found',
                  message: 'Try a different search or choose another category.',
                  icon: Icons.search_off,
                  actionLabel: 'Clear filters',
                  onAction: _clearFilters,
                ),
        ),
      ];
    }

    return [
      header(title, total: data.total),
      // A thin bar while a new filter loads; the old results stay below it.
      if (list.isLoading)
        const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
      SliverPadding(
        padding: padding,
        sliver: SliverAdaptiveGrid(
          itemCount: data.items.length,
          itemBuilder: (context, index) {
            final service = data.items[index];
            return ServiceCard(service: service, onTap: () => _open(service));
          },
        ),
      ),
      if (data.isLoadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      if (data.loadMoreFailure != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: MessageBanner(
              message: data.loadMoreFailure!.userMessage,
              onRetry: () =>
                  unawaited(ref.read(serviceListProvider.notifier).loadMore()),
            ),
          ),
        ),
    ];
  }
}
