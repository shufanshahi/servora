import 'package:material_ui/material_ui.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_card.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/presentation/widgets/service_image.dart';

/// Price and length of a service on one line, for example "$65 · 1 h".
class PriceAndDuration extends StatelessWidget {
  const PriceAndDuration({required this.service, super.key});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatPrice(service.price),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: '  ·  ${formatDuration(service.durationMinutes)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
      semanticLabel:
          '${service.name}, ${formatPrice(service.price)}, '
          '${formatDuration(service.durationMinutes)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: ServiceImage(
                url: service.imageUrl,
                semanticLabel: service.name,
                aspectRatio: 1,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                PriceAndDuration(service: service),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A service in the highlighted "Featured" row: a larger picture over the details.
class FeaturedServiceCard extends StatelessWidget {
  const FeaturedServiceCard({
    required this.service,
    required this.onTap,
    super.key,
  });

  static const width = 220.0;

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: AppCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        semanticLabel:
            'Featured: ${service.name}, ${formatPrice(service.price)}, '
            '${formatDuration(service.durationMinutes)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ServiceImage(url: service.imageUrl, semanticLabel: service.name),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  PriceAndDuration(service: service),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A grey stand-in for a [ServiceCard] while the list is loading. It is static on
/// purpose: no animation to distract, and nothing that keeps running.
class ServiceCardSkeleton extends StatelessWidget {
  const ServiceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
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
        padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(104, 104),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(double.infinity, 18),
                  const SizedBox(height: AppSpacing.sm),
                  bar(double.infinity, 12),
                  const SizedBox(height: AppSpacing.xs),
                  bar(160, 12),
                  const SizedBox(height: AppSpacing.md),
                  bar(90, 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
