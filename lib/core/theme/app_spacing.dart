import 'package:material_ui/material_ui.dart';

/// Spacing, radius and sizing tokens. Use these instead of literal numbers so the
/// whole app stays on one scale.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal gutter used by screens.
  static const double screenGutter = 20;

  /// Smallest comfortable touch target (Material and WCAG guidance).
  static const double minTouchTarget = 48;
}

abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;
}

/// Durations and curves for motion. Short and decelerating: things arrive quickly and
/// settle gently, which feels responsive rather than showy.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 560);

  /// Delay between items of a staggered entrance.
  static const Duration stagger = Duration(milliseconds: 55);

  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
  static const Curve standard = Curves.easeOutCubic;
}
