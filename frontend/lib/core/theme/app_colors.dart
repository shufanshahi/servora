import 'package:material_ui/material_ui.dart';

/// Brand colour tokens. The full Material colour scheme is derived from [seed].
abstract final class AppColors {
  static const Color seed = Color(0xFF0F766E); // deep teal

  static const Color background = Color(0xFFF7F9F9);
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF1B7F4B);
}

/// Foreground/background pair for a status chip. Chosen so text on background has
/// a contrast ratio of at least 4.5:1.
class StatusColors {
  const StatusColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

/// One distinct colour pair for each booking status.
abstract final class BookingStatusPalette {
  static const StatusColors pending = StatusColors(
    background: Color(0xFFFFF1CC),
    foreground: Color(0xFF7A4B00),
  );
  static const StatusColors confirmed = StatusColors(
    background: Color(0xFFD8F3E3),
    foreground: Color(0xFF0B5B33),
  );
  static const StatusColors cancelled = StatusColors(
    background: Color(0xFFFBDDDA),
    foreground: Color(0xFF8C1D18),
  );
  static const StatusColors completed = StatusColors(
    background: Color(0xFFDCE7F9),
    foreground: Color(0xFF1F3F7A),
  );
}
