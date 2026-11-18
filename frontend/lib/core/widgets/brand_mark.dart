import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_theme.dart';

/// The Servora logo: a serif "S" on a gold tile, with the wordmark beside it.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44, this.onDark = true});

  final double size;

  /// Light wordmark, for the emerald backgrounds.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Servora',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandTile(size: size),
          SizedBox(width: size * 0.3),
          // A logo, not body text: it scales down to fit rather than wrapping.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Servora',
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w600,
                  fontSize: size * 0.62,
                  letterSpacing: 0.2,
                  color: onDark ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Just the gold "S" tile.
class BrandTile extends StatelessWidget {
  const BrandTile({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.35),
            blurRadius: size * 0.5,
            offset: Offset(0, size * 0.15),
          ),
        ],
      ),
      child: Text(
        'S',
        style: TextStyle(
          fontFamily: AppTheme.displayFont,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.6,
          height: 1.05,
          color: AppColors.primaryDeep,
        ),
      ),
    );
  }
}

/// Soft concentric rings for depth on the emerald backgrounds.
class RingsPainter extends CustomPainter {
  const RingsPainter({this.origin = const Alignment(0.95, -0.9)});

  final Alignment origin;

  @override
  void paint(Canvas canvas, Size size) {
    final center = origin.alongSize(size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 6; i++) {
      paint.color = AppColors.goldLight.withValues(alpha: 0.15 - i * 0.02);
      canvas.drawCircle(center, 52.0 * i, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RingsPainter oldDelegate) =>
      oldDelegate.origin != origin;
}
