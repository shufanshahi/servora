import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';

/// A frosted-glass circle for an icon button that sits over a photo, such as Back on
/// a detail page. [dark] gives a solid ink circle instead, for light backgrounds.
class GlassCircle extends StatelessWidget {
  const GlassCircle({required this.child, super.key, this.dark = false});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dark ? AppColors.ink : Colors.white.withValues(alpha: 0.2),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0 : 0.35),
        ),
      ),
      child: IconTheme.merge(
        data: const IconThemeData(color: Colors.white, size: 20),
        child: child,
      ),
    );
    if (dark) return circle;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: circle,
      ),
    );
  }
}
