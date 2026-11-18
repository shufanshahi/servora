import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/motion.dart';

/// Surface used for list items and grouped content: white, softly shadowed, with a
/// hairline border. Tappable cards get an ink ripple clipped to the card shape and
/// press slightly inwards under a finger.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.semanticLabel,
    this.radius = AppRadius.lg,
    this.color = AppColors.surface,
    this.shadow = AppShadows.soft,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Spoken description for screen readers when the card is tappable.
  final String? semanticLabel;
  final double radius;
  final Color color;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: AppColors.outline.withValues(alpha: 0.7)),
    );
    final content = Padding(padding: padding, child: child);

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : Semantics(
                button: true,
                label: semanticLabel,
                child: InkWell(
                  onTap: onTap,
                  splashColor: AppColors.primary.withValues(alpha: 0.06),
                  highlightColor: AppColors.primary.withValues(alpha: 0.03),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                    child: content,
                  ),
                ),
              ),
      ),
    );

    return onTap == null ? card : PressableScale(child: card);
  }
}

/// A small uppercase label above a group of content, for example "FEATURED".
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color ?? AppColors.gold, letterSpacing: 1.6),
    );
  }
}

/// A heading for a section of a page, with an optional trailing note such as a count.
/// Wraps instead of overflowing when text is very large.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.trailing,
    this.eyebrow,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: AppSpacing.xs,
      spacing: AppSpacing.md,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              Eyebrow(eyebrow!),
              const SizedBox(height: 2),
            ],
            Semantics(
              container: true,
              header: true,
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22),
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }
}
