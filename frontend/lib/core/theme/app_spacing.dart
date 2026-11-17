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
  static const double screenGutter = md;

  /// Smallest comfortable touch target (Material and WCAG guidance).
  static const double minTouchTarget = 48;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double pill = 999;
}
