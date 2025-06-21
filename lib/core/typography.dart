import 'package:flutter/material.dart';

class AtaraxiaTypography {
  static TextTheme get light => _base(Colors.black87);
  static TextTheme get dark => _base(Colors.white70);

  static TextTheme _base(Color color) {
    return TextTheme(
      bodyLarge: TextStyle(
        fontSize: 20,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        height: 1.5,
        color: color.withOpacity(0.85),
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        letterSpacing: 0.4,
        color: color.withOpacity(0.6),
      ),
    );
  }
}
