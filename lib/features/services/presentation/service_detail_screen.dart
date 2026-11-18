import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/glass.dart';
import 'package:servora/core/widgets/loading_view.dart';
import 'package:servora/core/widgets/motion.dart';
import 'package:servora/features/booking/presentation/booking_providers.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/presentation/services_providers.dart';
import 'package:servora/features/services/presentation/widgets/category_chips.dart';
import 'package:servora/features/services/presentation/widgets/service_image.dart';

/// What a list passes when it opens a service: the tapped copy (so the page shows at
/// once) and which picture it should fly from.
class ServiceDetailExtra {
  const ServiceDetailExtra({required this.service, this.heroScope = 'list'});

  final Service service;

  /// Matches the `scope` the tapped card used for [serviceHeroTag].
  final String heroScope;
}

/// Everything about one service, with a clear way to start booking it.
///
/// [initial] is the copy the user just tapped in the list. It is shown immediately, and
/// the screen quietly refreshes it from the API. Without it (a direct link) the screen
/// shows a loading indicator until the service arrives.
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({
    required this.serviceId,
    super.key,
    this.initial,
    this.heroScope = 'list',
  });

  final String serviceId;
  final Service? initial;
  final String heroScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(serviceDetailProvider(serviceId));
    final failure = detail.hasError && !detail.isLoading ? detail.error : null;

    // A service that no longer exists must not be bookable from a stale copy.
    final gone = failure is NotFoundFailure;
    final service = gone ? null : (detail.value ?? initial);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: service != null
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBodyBehindAppBar: service != null,
        appBar: AppBar(
          backgroundColor: service != null ? Colors.transparent : null,
          automaticallyImplyLeading: false,
          leading: Navigator.of(context).canPop()
              ? Center(
                  child: GlassCircle(
                    dark: service == null,
                    child: const BackButton(color: Colors.white),
                  ),
                )
              : null,
          title: service == null ? const Text('Service details') : null,
        ),
        body: MaxContentWidth(
          child: service != null
              ? _Content(service: service, heroScope: heroScope)
              : SafeArea(
                  child: failure != null
                      ? ErrorView(
                          message: userMessageFor(failure),
                          onRetry: gone
                              ? null
                              : () => ref.invalidate(
                                  serviceDetailProvider(serviceId),
                                ),
                        )
                      : const LoadingView(message: 'Loading service'),
                ),
        ),
        bottomNavigationBar: service == null
            ? null
            : _BookBar(
                onBook: () => context.push(AppRoutes.serviceBook(service.id)),
              ),
      ),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content({required this.service, required this.heroScope});

  final Service service;
  final String heroScope;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = widget.service;
    final size = MediaQuery.sizeOf(context);
    // Tall enough to feel immersive, short enough to leave the name on screen.
    final headerHeight = (size.height * 0.48).clamp(240.0, 440.0);
    const sheetOverlap = 28.0;
    final animate = !reduceMotion(context);

    return ListView(
      controller: _scroll,
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: headerHeight,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // Parallax: the photo drifts at half speed as the page scrolls, and
              // grows when the page is pulled down past the top.
              AnimatedBuilder(
                animation: _scroll,
                builder: (context, child) {
                  final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                  if (!animate) return child!;
                  if (offset < 0) {
                    return Transform.scale(
                      scale: 1 + (-offset / headerHeight),
                      alignment: Alignment.bottomCenter,
                      child: child,
                    );
                  }
                  return Transform.translate(
                    offset: Offset(0, offset * 0.45),
                    child: child,
                  );
                },
                child: ServiceImage(
                  url: service.imageUrl,
                  semanticLabel: service.name,
                  aspectRatio: null,
                  heroTag: serviceHeroTag(service.id, scope: widget.heroScope),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.3, 0.7, 1],
                    colors: [
                      Color(0x8C000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x40000000),
                    ],
                  ),
                ),
              ),
              // The top of the content sheet, overlapping the photo.
              Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                height: sheetOverlap,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(sheetOverlap),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ColoredBox(
          color: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.xs,
              AppSpacing.screenGutter,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Semantics(
                      container: true,
                      child: _CategoryPill(category: service.category),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      service.name,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: _Facts(service: service),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        eyebrow: 'The experience',
                        title: 'About this service',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        container: true,
                        child: Text(
                          service.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.ink.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _GoodToKnow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(categoryIcon(category), size: 15, color: AppColors.gold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              category,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF7D5E2E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Price and duration side by side, or stacked when text is very large.
class _Facts extends StatelessWidget {
  const _Facts({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final price = _Fact(
      icon: Icons.payments_outlined,
      label: 'Price',
      value: formatPrice(service.price),
    );
    final duration = _Fact(
      icon: Icons.schedule_rounded,
      label: 'Duration',
      value: formatDuration(service.durationMinutes),
    );
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          price,
          const SizedBox(height: AppSpacing.sm),
          duration,
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: price),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(child: duration),
        ],
      ),
    );
  }
}

/// One labelled fact (price, duration) on a soft white tile.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: AppCard(
        radius: AppRadius.md + 4,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm + 2),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            // Flexible, so very large text wraps inside the tile instead of overflowing.
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Facts about booking that hold for every service.
class _GoodToKnow extends StatelessWidget {
  const _GoodToKnow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(IconData icon, String text) => MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.gold),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return AppCard(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 4,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good to know', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          row(
            Icons.event_available_outlined,
            'Choose any open time in the next $bookingHorizonDays days.',
          ),
          row(
            Icons.undo_rounded,
            'Free cancellation while your booking is still pending.',
          ),
          row(
            Icons.verified_outlined,
            'Every booking is confirmed by the provider.',
          ),
        ],
      ),
    );
  }
}

/// The always-visible bar with the main action.
class _BookBar extends StatelessWidget {
  const _BookBar({required this.onBook});

  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: MaxContentWidth(
          // Only as tall as the button, or it would crowd out the page above it.
          fillHeight: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.md,
              AppSpacing.screenGutter,
              AppSpacing.md,
            ),
            child: AppButton(
              label: 'Book this service',
              icon: Icons.calendar_month_outlined,
              onPressed: onBook,
            ),
          ),
        ),
      ),
    );
  }
}
