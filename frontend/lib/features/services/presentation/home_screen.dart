import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/brand_mark.dart';
import 'package:servora/core/widgets/empty_view.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/message_banner.dart';
import 'package:servora/core/widgets/motion.dart';
import 'package:servora/features/booking/presentation/booking_providers.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/presentation/service_detail_screen.dart';
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

  void _open(Service service, {String heroScope = 'list'}) {
    unawaited(
      context.push(
        AppRoutes.serviceDetail(service.id),
        extra: ServiceDetailExtra(service: service, heroScope: heroScope),
      ),
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

    final session = ref.watch(sessionProvider);
    final name = session is SessionAuthenticated ? session.user.name : null;
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons over the dark header.
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: topInset,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(
                name: name,
                now: ref.read(nowProvider)(),
                topInset: topInset,
                search: ServiceSearchField(
                  controller: _search,
                  focusNode: _searchFocus,
                  onChanged: filterNotifier.queryChanged,
                  onSubmitted: filterNotifier.submitQuery,
                  onClear: () {
                    _search.clear();
                    filterNotifier.submitQuery('');
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: CategoryChips(
                    categories: categories,
                    selected: filter.category,
                    onSelected: filterNotifier.setCategory,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenGutter,
                    ),
                  ),
                ),
              ),
            ),
            if (filter.isEmpty) ..._featuredSlivers(theme),
            ..._resultSlivers(theme, filter.isEmpty, list),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }

  List<Widget> _featuredSlivers(ThemeData theme) {
    final services = ref.watch(featuredServicesProvider).value;
    // Featured is a bonus: nothing is shown while it loads or if it fails.
    if (services == null || services.isEmpty) return const [];
    return [
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.xl,
            AppSpacing.screenGutter,
            AppSpacing.md,
          ),
          child: SectionHeader(
            eyebrow: 'Handpicked for you',
            title: 'Featured',
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, service) in services.indexed) ...[
                  FadeSlideIn.staggered(
                    index: index,
                    baseDelay: const Duration(milliseconds: 160),
                    offset: const Offset(48, 0),
                    child: FeaturedServiceCard(
                      service: service,
                      onTap: () => _open(service, heroScope: 'featured'),
                    ),
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
    const padding = EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter);

    // SectionHeader wraps: with very large text the count drops under the title
    // instead of overflowing the screen.
    Widget header(String title, {int? total}) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.lg + 4,
          AppSpacing.screenGutter,
          AppSpacing.md,
        ),
        child: SectionHeader(
          eyebrow: noFilter ? 'The full menu' : 'Your search',
          title: title,
          trailing: total == null
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    total == 1 ? '1 service' : '$total services',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
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
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              0,
              AppSpacing.screenGutter,
              AppSpacing.sm,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ),
        ),
      SliverPadding(
        padding: padding,
        sliver: SliverAdaptiveGrid(
          itemCount: data.items.length,
          itemBuilder: (context, index) {
            final service = data.items[index];
            // The first screenful arrives in a gentle cascade; cards further down
            // (built as the user scrolls) just fade up without waiting.
            return FadeSlideIn.staggered(
              index: index < 6 ? index : 0,
              baseDelay: const Duration(milliseconds: 120),
              child: ServiceCard(service: service, onTap: () => _open(service)),
            );
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

/// The dark emerald header at the top of Home: a greeting, the page title and the
/// search box, over the brand gradient with a few soft gold rings for depth.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.name,
    required this.now,
    required this.topInset,
    required this.search,
  });

  final String? name;
  final DateTime now;
  final double topInset;
  final Widget search;

  String get _greeting {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = (name ?? '').trim().split(RegExp(r'\s+')).first;
    final initial = first.isEmpty ? null : first.characters.first.toUpperCase();

    return Stack(
      children: [
        Positioned.fill(
          bottom: 28,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.xl + 4),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.xl + 4),
              ),
              child: const CustomPaint(painter: RingsPainter()),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            topInset + AppSpacing.md,
            AppSpacing.screenGutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                offset: const Offset(0, -12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            first.isEmpty ? _greeting : '$_greeting,',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                          if (first.isNotEmpty)
                            Text(
                              first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (initial != null) _Monogram(initial: initial),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow(
                      'Servora concierge',
                      color: AppColors.goldLight,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      container: true,
                      header: true,
                      // The display title grows with the user's text size, up to a
                      // point: past 1.6x it would push the search box off screen.
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.6,
                        child: Text(
                          'Find a service',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Premium care, beautifully booked.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: search,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The user's initial in a gold-ringed circle.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.goldGradient,
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryDeep,
          ),
          child: Text(
            initial,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.goldLight,
              fontFamily: 'Playfair Display',
            ),
          ),
        ),
      ),
    );
  }
}
