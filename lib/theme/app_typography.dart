import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextStyle get _inter => GoogleFonts.inter();
  static TextStyle get _jetBrainsMono => GoogleFonts.jetBrainsMono();

  static TextTheme buildTextTheme() {
    return TextTheme(
      displayLarge: _inter.copyWith(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25),
      displayMedium: _inter.copyWith(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: _inter.copyWith(fontSize: 36, fontWeight: FontWeight.w400),
      headlineLarge: _inter.copyWith(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2),
      headlineMedium: _inter.copyWith(fontSize: 26, fontWeight: FontWeight.w600, height: 1.25),
      headlineSmall: _inter.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: _inter.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
      titleMedium: _inter.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
      titleSmall: _inter.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      labelLarge: _inter.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2),
      labelMedium: _inter.copyWith(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
      labelSmall: _inter.copyWith(fontSize: 10, fontWeight: FontWeight.w600, height: 1.1),
      bodyLarge: _jetBrainsMono.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium: _jetBrainsMono.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: _jetBrainsMono.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
    );
  }

  static TextStyle mono({double fontSize = 13, FontWeight fontWeight = FontWeight.w400, Color? color}) {
    return _jetBrainsMono.copyWith(fontSize: fontSize, fontWeight: fontWeight, color: color);
  }

  static TextStyle inter({double fontSize = 14, FontWeight fontWeight = FontWeight.w400, Color? color}) {
    return _inter.copyWith(fontSize: fontSize, fontWeight: fontWeight, color: color);
  }
}
