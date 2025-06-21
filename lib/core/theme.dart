import 'package:flutter/material.dart';
import 'typography.dart';
import 'palette.dart';

class AtaraxiaTheme {
  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F6F4),
      textTheme: AtaraxiaTypography.light,
      useMaterial3: true,
    );
  }

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AtaraxiaPalette.voidDeep,
      textTheme: AtaraxiaTypography.dark,
      useMaterial3: true,
    );
  }
}
