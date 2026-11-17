import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_spacing.dart';

/// A scrolling row of category choices. "All" is always first; choosing the active
/// category again returns to "All".
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> categories;
  final String? selected;

  /// Called with the chosen category, or null for "All".
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', selected == null, () => onSelected(null)),
          for (final category in categories) ...[
            const SizedBox(width: AppSpacing.sm),
            _chip(
              category,
              selected == category,
              () => onSelected(selected == category ? null : category),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}
