import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/motion.dart';

enum AppButtonVariant { primary, secondary, text }

/// The one button used across the app. Shows a spinner and ignores taps while
/// [isLoading], which also prevents accidental double submits.
///
/// The primary variant carries a soft emerald glow and presses inwards slightly.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  /// Fill the available width (default) or size to the content.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = _buildChild(context);

    Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        // While loading, keep the brand colour instead of the grey disabled look.
        style: isLoading
            ? FilledButton.styleFrom(
                disabledBackgroundColor: AppColors.primary,
                disabledForegroundColor: Colors.white,
              )
            : null,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
    };

    if (variant == AppButtonVariant.primary) {
      button = AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: effectiveOnPressed != null || isLoading
              ? AppShadows.glow
              : const [],
        ),
        child: button,
      );
    }

    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      label: isLoading ? '$label, loading' : label,
      excludeSemantics: true,
      child: PressableScale(
        enabled: effectiveOnPressed != null,
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }

  Widget _buildChild(BuildContext context) {
    final Widget content;
    if (isLoading) {
      content = SizedBox(
        key: const ValueKey('loading'),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: variant == AppButtonVariant.primary ? Colors.white : null,
        ),
      );
    } else if (icon == null) {
      content = Text(label, key: const ValueKey('label'));
    } else {
      content = Row(
        key: const ValueKey('label'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(label)),
        ],
      );
    }
    return content;
  }
}
