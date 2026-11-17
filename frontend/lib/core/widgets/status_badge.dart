import 'package:material_ui/material_ui.dart';
import 'package:servora/core/domain/booking_status.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';

/// Small pill showing a booking status. Every screen uses this one widget so a
/// status always looks the same. Colour is paired with an icon and a text label so
/// the status never relies on colour alone.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(status);
    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xs,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: style.colors.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 14, color: style.colors.foreground),
            const SizedBox(width: AppSpacing.xs),
            // Flexible, so with very large text the label wraps instead of overflowing.
            Flexible(
              child: Text(
                status.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: style.colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static ({StatusColors colors, IconData icon}) _styleFor(
    BookingStatus status,
  ) {
    return switch (status) {
      BookingStatus.pending => (
        colors: BookingStatusPalette.pending,
        icon: Icons.schedule,
      ),
      BookingStatus.confirmed => (
        colors: BookingStatusPalette.confirmed,
        icon: Icons.check_circle_outline,
      ),
      BookingStatus.cancelled => (
        colors: BookingStatusPalette.cancelled,
        icon: Icons.cancel_outlined,
      ),
      BookingStatus.completed => (
        colors: BookingStatusPalette.completed,
        icon: Icons.task_alt,
      ),
    };
  }
}
