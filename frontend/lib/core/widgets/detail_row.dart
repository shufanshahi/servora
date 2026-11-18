import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';

/// One labelled line of a receipt-like card: an icon, a label, and the value on the
/// right. Wraps the value under the label when text is very large.
class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  /// A plain text value, styled consistently.
  factory DetailRow.text({
    required IconData icon,
    required String label,
    required String value,
    Key? key,
  }) => DetailRow(
    key: key,
    icon: icon,
    label: label,
    value: Builder(
      builder: (context) => Text(
        value,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
    ),
  );

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: AppSpacing.xs,
                spacing: AppSpacing.md,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  value,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dashed horizontal rule with half-circle notches at both ends, like the tear line
/// of a ticket. [notchColor] should match the page behind the card.
class TicketDivider extends StatelessWidget {
  const TicketDivider({super.key, this.notchColor = AppColors.background});

  final Color notchColor;

  @override
  Widget build(BuildContext context) {
    const notch = 12.0;
    return SizedBox(
      height: notch * 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: notch + 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const dash = 6.0;
                final count = (constraints.maxWidth / (dash * 2)).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    count,
                    (_) => Container(
                      width: dash,
                      height: 1.4,
                      color: AppColors.outline,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: -notch - 1,
            child: _Notch(color: notchColor, size: notch * 2),
          ),
          Positioned(
            right: -notch - 1,
            child: _Notch(color: notchColor, size: notch * 2),
          ),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
