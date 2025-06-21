import 'package:flutter/material.dart';

class SeasonalTint {
  // 🚀 Optional: Pass the string from the database (e.g. "autumn", "winter")
  static ColorFilter filter({String? dbSeason}) {
    String currentSeason = dbSeason?.toLowerCase() ?? _getCurrentSeason();

    switch (currentSeason) {
      case 'winter':
        return ColorFilter.mode(
          Colors.blueGrey.withOpacity(0.08),
          BlendMode.overlay,
        );
      case 'spring':
        return ColorFilter.mode(
          Colors.greenAccent.withOpacity(0.04),
          BlendMode.overlay,
        );
      case 'summer':
        return ColorFilter.mode(
          Colors.deepOrange.withOpacity(0.06),
          BlendMode.overlay,
        );
      case 'autumn':
      case 'fall':
        return ColorFilter.mode(
          Colors.brown.withOpacity(0.08),
          BlendMode.overlay,
        );
      default:
        return const ColorFilter.mode(Colors.transparent, BlendMode.overlay);
    }
  }

  static String _getCurrentSeason() {
    final month = DateTime.now().month;
    if (month == 12 || month <= 2) return 'winter';
    if (month <= 5) return 'spring';
    if (month <= 8) return 'summer';
    return 'autumn';
  }
}
