import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/layout/responsive.dart';
import 'package:servora/core/theme/app_colors.dart';
import 'package:servora/core/theme/app_spacing.dart';
import 'package:servora/core/widgets/brand_mark.dart';
import 'package:servora/core/widgets/motion.dart';

/// The frame shared by sign-in and registration: an emerald header with the brand
/// and a short promise, then the form on an ivory sheet that rises over it.
///
/// Everything scrolls together, so the form stays usable on small screens, in
/// landscape and with very large text.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;

  /// The form.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    const sheetRadius = AppRadius.xl;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header.
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppColors.heroGradient,
                ),
                child: CustomPaint(
                  painter: const RingsPainter(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      topInset + AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl + sheetRadius,
                    ),
                    child: MaxContentWidth(
                      fillHeight: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FadeSlideIn(
                            offset: Offset(0, -16),
                            child: BrandMark(),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 80),
                            child: Text(
                              'Refined care,\nbeautifully booked.',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppColors.goldLight,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Sheet with the form, rising over the bottom of the header.
              Transform.translate(
                offset: const Offset(0, -sheetRadius),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(sheetRadius),
                    ),
                  ),
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height * 0.6,
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: MaxContentWidth(
                    fillHeight: false,
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      offset: const Offset(0, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            container: true,
                            header: true,
                            child: Text(
                              title,
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
