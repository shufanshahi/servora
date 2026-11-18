import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/brand_mark.dart';
import 'package:servora/core/widgets/motion.dart';

/// The splash screen shown while the saved session is being restored: the brand on
/// the emerald gradient, easing in.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: CustomPaint(
            painter: const RingsPainter(origin: Alignment.center),
            child: Center(
              child: Semantics(
                label: 'Starting Servora',
                liveRegion: true,
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FadeSlideIn(
                        offset: Offset(0, 16),
                        child: BrandTile(size: 76),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: Text(
                          'Servora',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.goldLight.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Starting Servora',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
