import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';

/// An icon that suits a category name. Unknown categories get a neutral sparkle, so a
/// new category from the API still looks at home.
IconData categoryIcon(String? category) {
  final name = (category ?? '').toLowerCase();
  if (name.contains('well') || name.contains('spa')) return Icons.spa_outlined;
  if (name.contains('beauty') || name.contains('hair')) {
    return Icons.face_retouching_natural_outlined;
  }
  if (name.contains('home') || name.contains('clean')) {
    return Icons.cottage_outlined;
  }
  if (name.contains('tech') || name.contains('repair')) {
    return Icons.devices_other_outlined;
  }
  if (name.contains('garden')) return Icons.yard_outlined;
  return Icons.auto_awesome_outlined;
}

/// A scrolling row of category choices. "All" is always first; choosing the active
/// category again returns to "All".
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
    super.key,
    this.padding = EdgeInsets.zero,
  });

  final List<String> categories;
  final String? selected;

  /// Called with the chosen category, or null for "All".
  final ValueChanged<String?> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _chip(
            'All',
            Icons.grid_view_rounded,
            selected == null,
            () => onSelected(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: AppSpacing.sm),
            _chip(
              category,
              categoryIcon(category),
              selected == category,
              () => onSelected(selected == category ? null : category),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? AppColors.goldLight : AppColors.inkMuted,
      ),
      label: Text(label),
      selected: isSelected,
      elevation: 0,
      pressElevation: 0,
      onSelected: (_) => onTap(),
    );
  }
}
