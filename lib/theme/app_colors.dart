import 'package:flutter/material.dart';

class AppColors {
  // Accent color used across all themes
  static const Color accent = Color(0xFF22D3EE);
  static const Color accentLight = Color(0xFF0891B2);

  // Status colors
  static const Color success = Color(0xFF4ADE80);
  static const Color successLight = Color(0xFF10B981);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);
  static const Color errorLight = Color(0xFFEF4444);

  // Language tag colors
  static const Map<String, Color> languageColors = {
    'Rust': Color(0xFFDEA584),
    'Flutter': Color(0xFF54C5F8),
    'Dart': Color(0xFF00B4AB),
    'React': Color(0xFF61DAFB),
    'NodeJS': Color(0xFF68A063),
    'Python': Color(0xFFFFD43B),
    'Go': Color(0xFF00ADD8),
    'Ruby': Color(0xFFCC342D),
    'PHP': Color(0xFF777BB4),
    'Java': Color(0xFFED8B00),
    'Kotlin': Color(0xFF7F52FF),
    'Swift': Color(0xFFFA7343),
    'TypeScript': Color(0xFF3178C6),
    'JavaScript': Color(0xFFF7DF1E),
    'C++': Color(0xFF00599C),
    'C': Color(0xFF555555),
    'Markdown': Color(0xFF6B7280),
    'Bash': Color(0xFF4EAA25),
    'Shell': Color(0xFF4EAA25),
  };

  static Color getLanguageColor(String language) {
    return languageColors[language] ?? const Color(0xFF6B7280);
  }
}

class DarkColors {
  static const Color primary = Color(0xFFF9FAFB);
  static const Color onPrimary = Color(0xFF000000);
  static const Color secondary = Color(0xFF9CA3AF);
  static const Color onSecondary = Color(0xFF000000);
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceContainer = Color(0xFF1A1A1A);
  static const Color onSurface = Color(0xFFF3F4F6);
  static const Color onSurfaceVariant = Color(0xFF9CA3AF);
  static const Color primaryText = Color(0xFFF3F4F6);
  static const Color secondaryText = Color(0xFF9CA3AF);
  static const Color hint = Color(0xFF4B5563);
  static const Color divider = Color(0xFF262626);
  static const Color outline = Color(0xFF374151);
}

class LightColors {
  static const Color primary = Color(0xFF1A1A1A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFF4B5563);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFF3F4F6);
  static const Color onSurface = Color(0xFF111827);
  static const Color onSurfaceVariant = Color(0xFF6B7280);
  static const Color primaryText = Color(0xFF111827);
  static const Color secondaryText = Color(0xFF6B7280);
  static const Color hint = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color outline = Color(0xFFD1D5DB);
}

class MidnightColors {
  static const Color primary = Color(0xFFB388FF);
  static const Color onPrimary = Color(0xFF1A0033);
  static const Color secondary = Color(0xFFCE93D8);
  static const Color background = Color(0xFF080010);
  static const Color surface = Color(0xFF11001C);
  static const Color surfaceContainer = Color(0xFF1A0A2E);
  static const Color onSurface = Color(0xFFE8DEF8);
  static const Color onSurfaceVariant = Color(0xFFD0BCFF);
  static const Color divider = Color(0xFF2D1B69);
  static const Color outline = Color(0xFF7E57C2);
}

class OceanColors {
  static const Color primary = Color(0xFF90CAF9);
  static const Color onPrimary = Color(0xFF003258);
  static const Color secondary = Color(0xFF81D4FA);
  static const Color background = Color(0xFF050E1A);
  static const Color surface = Color(0xFF0A1929);
  static const Color surfaceContainer = Color(0xFF0D2137);
  static const Color onSurface = Color(0xFFE3F2FD);
  static const Color onSurfaceVariant = Color(0xFFBBDEFB);
  static const Color divider = Color(0xFF0D47A1);
  static const Color outline = Color(0xFF1976D2);
}
