import 'package:material_ui/material_ui.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/core/widgets/motion.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/presentation/widgets/service_image.dart';

/// Price and length of a service, for example "$65" beside a "1 h" pill.
class PriceAndDuration extends StatelessWidget {
  const PriceAndDuration({
    required this.service,
    super.key,
    this.onDark = false,
  });

  final Service service;

  /// Light text, for use over a photo or a dark surface.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = onDark
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.inkMuted;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm + 2,
      runSpacing: AppSpacing.xs,
      children: [
        Text(
          formatPrice(service.price),
          style: theme.textTheme.titleMedium?.copyWith(
            color: onDark ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 15, color: muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                formatDuration(service.durationMinutes),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A service in the main list: picture on the left, details on the right.
class ServiceCard extends StatelessWidget {
  const ServiceCard({required this.service, required this.onTap, super.key});

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      semanticLabel:
          '${service.name}, ${formatPrice(service.price)}, '
          '${formatDuration(service.durationMinutes)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ServiceImage(
                url: service.imageUrl,
                semanticLabel: service.name,
                aspectRatio: 0.9,
                heroTag: serviceHeroTag(service.id),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(service.category),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    service.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    service.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: PriceAndDuration(service: service)),
                      const SizedBox(width: AppSpacing.xs),
                      const _ArrowBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The little round arrow at the end of a list card: "this opens".
class _ArrowBadge extends StatelessWidget {
  const _ArrowBadge();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// A service in the highlighted "Featured" row: a tall photo with the details laid
/// over a dark gradient at the bottom, like a magazine cover.
///
/// The photo fills the card and the text sets its height (with a generous minimum), so
/// very large text makes the card taller instead of overflowing it.
class FeaturedServiceCard extends StatelessWidget {
  const FeaturedServiceCard({
    required this.service,
    required this.onTap,
    super.key,
  });

  static const width = 240.0;
  static const minHeight = 280.0;

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: PressableScale(
        child: Semantics(
          button: true,
          label:
              'Featured: ${service.name}, ${formatPrice(service.price)}, '
              '${formatDuration(service.durationMinutes)}',
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.lifted,
            ),
            child: Material(
              color: AppColors.primaryDeep,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                splashColor: Colors.white.withValues(alpha: 0.08),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ServiceImage(
                        url: service.imageUrl,
                        semanticLabel: service.name,
                        aspectRatio: null,
                        heroTag: serviceHeroTag(service.id, scope: 'featured'),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.imageScrim,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: minHeight,
                        minWidth: width,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md + 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _GlassTag(
                              icon: Icons.auto_awesome_rounded,
                              label: 'Signature',
                            ),
                            const SizedBox(
                              height: AppSpacing.xxl + AppSpacing.lg,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Eyebrow(
                                  service.category,
                                  color: AppColors.goldLight,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  service.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontSize: 22,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                PriceAndDuration(
                                  service: service,
                                  onDark: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small frosted label over a photo.
class _GlassTag extends StatelessWidget {
  const _GlassTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.goldLight),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stand-in for a [ServiceCard] while the list is loading, in the same shape, with a
/// soft shimmer sweeping across it.
class ServiceCardSkeleton extends StatelessWidget {
  const ServiceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const color = AppColors.surfaceMuted;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );

    return ExcludeSemantics(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        child: Shimmer(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(104, 116),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    bar(64, 10),
                    const SizedBox(height: AppSpacing.sm),
                    bar(double.infinity, 18),
                    const SizedBox(height: AppSpacing.sm),
                    bar(double.infinity, 12),
                    const SizedBox(height: AppSpacing.xs),
                    bar(140, 12),
                    const SizedBox(height: AppSpacing.md),
                    bar(90, 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
