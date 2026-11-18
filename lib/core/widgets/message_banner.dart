import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_spacing.dart';

enum BannerTone { error, info }

/// Inline message for a form or screen: an error with an optional retry, or an
/// informational note. Announced to screen readers when it appears.
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    required this.message,
    super.key,
    this.tone = BannerTone.error,
    this.onRetry,
  });

  final String message;
  final BannerTone tone;

  /// Shows a "Try again" button when set.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = tone == BannerTone.error;
    final background = isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.info_outline,
                  color: foreground,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
            if (onRetry != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
