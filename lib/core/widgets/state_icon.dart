import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/widgets/motion.dart';

/// The illustration at the top of an empty, error or success state: an icon on a soft
/// circular halo that gently scales in.
class StateIcon extends StatelessWidget {
  const StateIcon({
    required this.icon,
    super.key,
    this.color = AppColors.primary,
    this.size = 96,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final halo = ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0.04),
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: size * 0.42, color: color),
      ),
    );
    if (reduceMotion(context)) return halo;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: halo,
    );
  }
}
