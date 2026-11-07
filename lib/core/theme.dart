import 'package:flutter/material.dart';

/// Derafsh visual identity — derived from the Derafsh-e Kaviani:
/// royal purple field, golden Kaviani star, crimson streamers.
/// See docs/DESIGN.md.
abstract final class DrfColors {
  static const Color bg = Color(0xFF150826);
  static const Color bgTop = Color(0xFF241040);
  static const Color bgBottom = Color(0xFF0E0518);
  static const Color surface = Color(0xFF221038);
  static const Color surfaceHi = Color(0xFF2C164C);
  static const Color stroke = Color(0xFF3A2160);

  static const Color gold = Color(0xFFE9B94E);
  static const Color goldHi = Color(0xFFFFE193);
  static const Color goldDeep = Color(0xFFA87B1F);
  static const Color goldInk = Color(0xFF2A1804); // text on gold
  static const Color goldRim = Color(0xFF7A5A16); // star outline
  static const Color goldInkSoft = Color(0xFFB5822A); // star center ring
  static const Color cream = Color(0xFFFFF3C8); // star core

  static const Color crimson = Color(0xFFD6455D);
  static const Color crimsonDeep = Color(0xFF7E2338);

  static const Color violet = Color(0xFF8B5CF6);

  static const Color text = Color(0xFFF5EDDF);
  static const Color textDim = Color(0xFFB3A2CE);
  static const Color textFaint = Color(0xFF7E6FA0);
}

abstract final class DrfGradients {
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [DrfColors.goldHi, DrfColors.gold, Color(0xFFC08A29)],
  );

  static const LinearGradient bg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [DrfColors.bgTop, DrfColors.bg, DrfColors.bgBottom],
    stops: [0.0, 0.35, 1.0],
  );

  static const RadialGradient farr = RadialGradient(
    colors: [Color(0x55E9B94E), Color(0x22E9B94E), Color(0x00E9B94E)],
    stops: [0.0, 0.45, 1.0],
  );
}

ThemeData buildDrafshTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Vazirmatn',
  );
  return base.copyWith(
    scaffoldBackgroundColor: DrfColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: DrfColors.gold,
      secondary: DrfColors.violet,
      surface: DrfColors.surface,
      error: DrfColors.crimson,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Vazirmatn',
      bodyColor: DrfColors.text,
      displayColor: DrfColors.text,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: DrfColors.surfaceHi,
      contentTextStyle: const TextStyle(fontFamily: 'Vazirmatn', color: DrfColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: DrfColors.stroke, thickness: 1),
  );
}
