import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';

/// The search box at the top of the home screen: a soft floating pill. A clear button
/// appears once there is text in it.
class ServiceSearchField extends StatelessWidget {
  const ServiceSearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final pill = BorderRadius.circular(AppRadius.lg);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: pill,
          borderSide: BorderSide(color: color, width: width),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: pill,
        boxShadow: AppShadows.lifted,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          hintText: 'Search services',
          prefixIcon: const Padding(
            padding: EdgeInsetsDirectional.only(start: 6),
            child: Icon(Icons.search_rounded, color: AppColors.primary),
          ),
          border: border(Colors.transparent),
          enabledBorder: border(Colors.transparent),
          focusedBorder: border(AppColors.gold, 1.4),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              );
            },
          ),
        ),
      ),
    );
  }
}
