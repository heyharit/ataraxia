import 'package:flutter/material.dart';

/// Ataraxia Cosmic Palette
/// All colors are calibrated to feel premium on OLED — deep but alive.
/// Glows stay 8–15% opacity so wallpaper imagery always dominates.
class AtaraxiaPalette {
  AtaraxiaPalette._();

  // ─── VOID BACKGROUNDS ───
  /// The deepest background — feels black on OLED but has subtle blue tonality
  static const Color voidDeep = Color(0xFF080910);

  /// Slightly lifted surface — used for cards, modals
  static const Color voidSurface = Color(0xFF0D0F18);

  /// Lifted card face
  static const Color cardSurface = Color(0xFF111420);

  // ─── AMBIENT GLOW COLOURS ───
  /// Top-right ambient orb — cosmic indigo
  static const Color cosmicIndigo = Color(0xFF4B5EE4);

  /// Bottom-left ambient orb — deep violet
  static const Color auroraViolet = Color(0xFF8B3FCF);

  /// Accent / selected states — glacial teal
  static const Color glacialTeal = Color(0xFF00E5CC);

  /// Warm gold accent for streaks / achievements
  static const Color sacredGold = Color(0xFFD4A843);

  // ─── GLASS / BORDER ELEMENTS ───
  /// Default glass edge
  static const Color glassEdge = Color(0x14FFFFFF); // white @ 8%

  /// Elevated glass edge
  static const Color glassEdgeBright = Color(0x26FFFFFF); // white @ 15%

  // ─── SEMANTIC HELPERS ───
  static Color indigoGlow(double opacity) =>
      cosmicIndigo.withOpacity(opacity);

  static Color violetGlow(double opacity) =>
      auroraViolet.withOpacity(opacity);

  static Color tealGlow(double opacity) =>
      glacialTeal.withOpacity(opacity);

  // ─── GRADIENT RECIPES ───
  /// The main ambient background gradient for scaffold backgrounds
  static const LinearGradient voidGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF0D0E1A), // indigo-tinted void
      Color(0xFF080910), // deep void
      Color(0xFF0A0810), // violet-tinted void
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Gradient for the glowing ring on the rotary dial
  static const SweepGradient dialRingGradient = SweepGradient(
    colors: [
      Color(0x334B5EE4), // indigo
      Color(0x3300E5CC), // teal
      Color(0x338B3FCF), // violet
      Color(0x334B5EE4), // back to indigo
    ],
  );

  /// Card inner gradient (subtle depth)
  static const LinearGradient cardInnerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x0CFFFFFF), // white @ 5%
      Color(0x04FFFFFF), // white @ 2%
    ],
  );

  /// Accent card gradient (teal-tinted)
  static const LinearGradient accentCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1400E5CC), // teal @ 8%
      Color(0x0800E5CC), // teal @ 3%
    ],
  );

  /// Progress bar gradient (indigo → teal)
  static const LinearGradient progressGradient = LinearGradient(
    colors: [cosmicIndigo, glacialTeal],
  );
}
