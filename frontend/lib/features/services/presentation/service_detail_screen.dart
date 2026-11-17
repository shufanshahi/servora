import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/format/formatters.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/app_button.dart';
import 'package:servora/core/widgets/error_view.dart';
import 'package:servora/core/widgets/loading_view.dart';
import 'package:servora/features/services/domain/service.dart';
import 'package:servora/features/services/presentation/services_providers.dart';
import 'package:servora/features/services/presentation/widgets/service_image.dart';

/// Everything about one service, with a clear way to start booking it.
///
/// [initial] is the copy the user just tapped in the list. It is shown immediately, and
/// the screen quietly refreshes it from the API. Without it (a direct link) the screen
/// shows a loading indicator until the service arrives.
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({required this.serviceId, super.key, this.initial});

  final String serviceId;
  final Service? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(serviceDetailProvider(serviceId));
    final failure = detail.hasError && !detail.isLoading ? detail.error : null;

    // A service that no longer exists must not be bookable from a stale copy.
    final gone = failure is NotFoundFailure;
    final service = gone ? null : (detail.value ?? initial);

    return Scaffold(
      appBar: AppBar(title: const Text('Service details')),
      body: SafeArea(
        child: MaxContentWidth(
          child: service != null
              ? _Content(service: service)
              : failure != null
              ? ErrorView(
                  message: userMessageFor(failure),
                  onRetry: gone
                      ? null
                      : () => ref.invalidate(serviceDetailProvider(serviceId)),
                )
              : const LoadingView(message: 'Loading service'),
        ),
      ),
      bottomNavigationBar: service == null
          ? null
          : _BookBar(
              onBook: () => context.push(AppRoutes.serviceBook(service.id)),
            ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ServiceImage(
            url: service.imageUrl,
            semanticLabel: service.name,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Chip(label: Text(service.category)),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          header: true,
          child: Text(service.name, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _Fact(
              icon: Icons.payments_outlined,
              label: 'Price',
              value: formatPrice(service.price),
            ),
            _Fact(
              icon: Icons.schedule,
              label: 'Duration',
              value: formatDuration(service.durationMinutes),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text('About this service', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(service.description, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// One labelled fact (price, duration) in a small rounded box.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            // Flexible, so very large text wraps inside the box instead of overflowing.
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
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

/// The always-visible bar with the main action.
class _BookBar extends StatelessWidget {
  const _BookBar({required this.onBook});

  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: MaxContentWidth(
          // Only as tall as the button, or it would crowd out the page above it.
          fillHeight: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(label: 'Book this service', onPressed: onBook),
          ),
        ),
      ),
    );
  }
}
