import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_typography.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

class AppRadius {
  static const double sm = 4.0;
  static const double md = 4.0;
  static const double lg = 8.0;
  static const double xl = 12.0;
  static const double full = 9999.0;
}

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 26.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 20.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 13.0;
  static const double labelMedium = 11.0;
  static const double labelSmall = 10.0;
  static const double bodyLarge = 14.0;
  static const double bodyMedium = 13.0;
  static const double bodySmall = 12.0;
}

enum AppTheme {
  light,
  dark,
  midnight,
  ocean,
}

extension AppThemeExtension on AppTheme {
  String get name {
    switch (this) {
      case AppTheme.light: return 'Light';
      case AppTheme.dark: return 'Dark';
      case AppTheme.midnight: return 'Midnight';
      case AppTheme.ocean: return 'Ocean';
    }
  }

  String get description {
    switch (this) {
      case AppTheme.light: return 'High contrast workspace';
      case AppTheme.dark: return 'Default system theme';
      case AppTheme.midnight: return 'Deep purple dark theme';
      case AppTheme.ocean: return 'Blue-tinted dark theme';
    }
  }

  bool get requiresUnlock {
    switch (this) {
      case AppTheme.light:
      case AppTheme.dark:
        return false;
      case AppTheme.midnight:
      case AppTheme.ocean:
        return true;
    }
  }

  String? get unlockRewardId {
    switch (this) {
      case AppTheme.light:
      case AppTheme.dark:
        return null;
      case AppTheme.midnight:
        return 'dark_theme_midnight';
      case AppTheme.ocean:
        return 'dark_theme_ocean';
    }
  }

  List<Color> get previewColors {
    switch (this) {
      case AppTheme.dark:
        return [DarkColors.background, DarkColors.surface, AppColors.accent];
      case AppTheme.light:
        return [LightColors.background, LightColors.surface, AppColors.accentLight];
      case AppTheme.midnight:
        return [MidnightColors.background, MidnightColors.surface, MidnightColors.primary];
      case AppTheme.ocean:
        return [OceanColors.background, OceanColors.surface, OceanColors.primary];
    }
  }

  ThemeData get themeData {
    switch (this) {
      case AppTheme.light: return _buildLightTheme();
      case AppTheme.dark: return _buildDarkTheme();
      case AppTheme.midnight: return _buildMidnightTheme();
      case AppTheme.ocean: return _buildOceanTheme();
    }
  }
}

ThemeData _buildDarkTheme() {
  final textTheme = AppTypography.buildTextTheme();
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DarkColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: DarkColors.onPrimary,
      secondary: DarkColors.secondary,
      onSecondary: DarkColors.onSecondary,
      error: AppColors.error,
      onError: DarkColors.onPrimary,
      surface: DarkColors.surface,
      onSurface: DarkColors.onSurface,
      surfaceContainerHighest: DarkColors.surfaceContainer,
      onSurfaceVariant: DarkColors.onSurfaceVariant,
      outline: DarkColors.outline,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: DarkColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: DarkColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: DarkColors.divider),
      ),
    ),
    dividerTheme: const DividerThemeData(color: DarkColors.divider, thickness: 1),
    textTheme: textTheme,
  );
}

ThemeData _buildLightTheme() {
  final textTheme = AppTypography.buildTextTheme();
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: LightColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accentLight,
      onPrimary: LightColors.onPrimary,
      secondary: LightColors.secondary,
      onSecondary: LightColors.onSecondary,
      error: AppColors.errorLight,
      onError: LightColors.onPrimary,
      surface: LightColors.surface,
      onSurface: LightColors.onSurface,
      surfaceContainerHighest: LightColors.surfaceContainer,
      onSurfaceVariant: LightColors.onSurfaceVariant,
      outline: LightColors.outline,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: LightColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: LightColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: LightColors.divider),
      ),
    ),
    dividerTheme: const DividerThemeData(color: LightColors.divider, thickness: 1),
    textTheme: textTheme,
  );
}

ThemeData _buildMidnightTheme() {
  final textTheme = AppTypography.buildTextTheme();
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: MidnightColors.background,
    colorScheme: ColorScheme.dark(
      primary: MidnightColors.primary,
      onPrimary: MidnightColors.onPrimary,
      secondary: MidnightColors.secondary,
      error: AppColors.error,
      surface: MidnightColors.surface,
      onSurface: MidnightColors.onSurface,
      surfaceContainerHighest: MidnightColors.surfaceContainer,
      onSurfaceVariant: MidnightColors.onSurfaceVariant,
      outline: MidnightColors.outline,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: MidnightColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: MidnightColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: MidnightColors.divider),
      ),
    ),
    dividerTheme: const DividerThemeData(color: MidnightColors.divider, thickness: 1),
    textTheme: textTheme,
  );
}

ThemeData _buildOceanTheme() {
  final textTheme = AppTypography.buildTextTheme();
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: OceanColors.background,
    colorScheme: ColorScheme.dark(
      primary: OceanColors.primary,
      onPrimary: OceanColors.onPrimary,
      secondary: OceanColors.secondary,
      error: AppColors.error,
      surface: OceanColors.surface,
      onSurface: OceanColors.onSurface,
      surfaceContainerHighest: OceanColors.surfaceContainer,
      onSurfaceVariant: OceanColors.onSurfaceVariant,
      outline: OceanColors.outline,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: OceanColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: OceanColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: OceanColors.divider),
      ),
    ),
    dividerTheme: const DividerThemeData(color: OceanColors.divider, thickness: 1),
    textTheme: textTheme,
  );
}
