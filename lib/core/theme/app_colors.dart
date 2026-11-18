import 'package:material_ui/material_ui.dart';

/// Brand colour tokens.
///
/// The palette is deliberately small: a warm ivory canvas, near-black ink for text, a
/// deep emerald for primary actions and a champagne gold used sparingly for accents.
abstract final class AppColors {
  /// Seed for the derived Material scheme (tones for containers, outlines, etc.).
  static const Color seed = Color(0xFF1B4D45);

  /// Deep emerald: primary actions, selected states, links.
  static const Color primary = Color(0xFF1B4D45);

  /// The darkest emerald, for immersive headers and the hero gradient.
  static const Color primaryDeep = Color(0xFF0C2622);

  /// Champagne gold accent. Readable on dark surfaces; used for icons and highlights
  /// (not body text) on light ones.
  static const Color gold = Color(0xFFB8925A);
  static const Color goldLight = Color(0xFFE2C79A);

  /// Near-black ink for text and the floating navigation bar.
  static const Color ink = Color(0xFF15171C);
  static const Color inkMuted = Color(0xFF656A73);

  static const Color background = Color(0xFFF6F3EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEFEAE2);
  static const Color outline = Color(0xFFE6DFD4);

  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF1B7F4B);

  /// The signature gradient behind headers, the sign-in hero and highlights.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, Color(0xFF16413A), Color(0xFF245E54)],
  );

  /// A soft gold sheen, for small premium accents.
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9D3A8), gold],
  );

  /// Darkens the bottom of a photo so white text on it stays readable.
  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.35, 1],
    colors: [Color(0x00000000), Color(0xD90B1210)],
  );
}

/// Soft, layered shadows. Large blur with low opacity reads as "premium" rather than
/// the hard drop shadow of default elevation.
abstract final class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0F1B2A26), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A1B2A26), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> lifted = [
    BoxShadow(color: Color(0x1F0C2622), blurRadius: 32, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x0F0C2622), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> glow = [
    BoxShadow(color: Color(0x401B4D45), blurRadius: 24, offset: Offset(0, 10)),
  ];
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
    background: Color(0xFFFBEFD5),
    foreground: Color(0xFF7A4B00),
  );
  static const StatusColors confirmed = StatusColors(
    background: Color(0xFFDCF1E5),
    foreground: Color(0xFF0B5B33),
  );
  static const StatusColors cancelled = StatusColors(
    background: Color(0xFFF9E0DD),
    foreground: Color(0xFF8C1D18),
  );
  static const StatusColors completed = StatusColors(
    background: Color(0xFFE0E8F5),
    foreground: Color(0xFF1F3F7A),
  );
}
