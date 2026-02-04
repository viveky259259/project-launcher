import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  // Spacing values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Edge insets shortcuts
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal padding
  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

/// Border radius constants for consistent rounded corners
class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

// =============================================================================
// TEXT STYLE EXTENSIONS
// =============================================================================

/// Extension to add text style utilities to BuildContext
/// Access via context.textStyles
extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

/// Helper methods for common text style modifications
extension TextStyleExtensions on TextStyle {
  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);

  /// Make text semi-bold
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);

  /// Make text medium weight
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// Make text normal weight
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);

  /// Make text light
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Add custom color
  TextStyle withColor(Color color) => copyWith(color: color);

  /// Add custom size
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// COLORS
// =============================================================================

/// Modern, neutral color palette for light mode
/// Uses soft grays and blues instead of purple for a contemporary look
class LightModeColors {
  // Primary: Soft blue-gray for a modern, professional look
  static const lightPrimary = Color(0xFF5B7C99);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFD8E6F3);
  static const lightOnPrimaryContainer = Color(0xFF1A3A52);

  // Secondary: Complementary gray-blue
  static const lightSecondary = Color(0xFF5C6B7A);
  static const lightOnSecondary = Color(0xFFFFFFFF);

  // Tertiary: Subtle accent color
  static const lightTertiary = Color(0xFF6B7C8C);
  static const lightOnTertiary = Color(0xFFFFFFFF);

  // Error colors
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);

  // Surface and background: High contrast for readability
  static const lightSurface = Color(0xFFFBFCFD);
  static const lightOnSurface = Color(0xFF1A1C1E);
  static const lightBackground = Color(0xFFF7F9FA);
  static const lightSurfaceVariant = Color(0xFFE2E8F0);
  static const lightOnSurfaceVariant = Color(0xFF44474E);

  // Outline and shadow
  static const lightOutline = Color(0xFF74777F);
  static const lightShadow = Color(0xFF000000);
  static const lightInversePrimary = Color(0xFFACC7E3);
}

/// Midnight theme colors (unlockable via referrals)
class MidnightThemeColors {
  static const midnightPrimary = Color(0xFFB388FF);
  static const midnightOnPrimary = Color(0xFF1A0033);
  static const midnightPrimaryContainer = Color(0xFF4A148C);
  static const midnightOnPrimaryContainer = Color(0xFFE1BEE7);
  static const midnightSecondary = Color(0xFFCE93D8);
  static const midnightOnSecondary = Color(0xFF2E1A47);
  static const midnightTertiary = Color(0xFFB39DDB);
  static const midnightOnTertiary = Color(0xFF311B92);
  static const midnightError = Color(0xFFFFB4AB);
  static const midnightOnError = Color(0xFF690005);
  static const midnightSurface = Color(0xFF11001C);
  static const midnightOnSurface = Color(0xFFE8DEF8);
  static const midnightSurfaceVariant = Color(0xFF2D1B69);
  static const midnightOnSurfaceVariant = Color(0xFFD0BCFF);
  static const midnightOutline = Color(0xFF7E57C2);
}

/// Ocean theme colors (unlockable via referrals)
class OceanThemeColors {
  static const oceanPrimary = Color(0xFF90CAF9);
  static const oceanOnPrimary = Color(0xFF003258);
  static const oceanPrimaryContainer = Color(0xFF0277BD);
  static const oceanOnPrimaryContainer = Color(0xFFBBDEFB);
  static const oceanSecondary = Color(0xFF81D4FA);
  static const oceanOnSecondary = Color(0xFF01579B);
  static const oceanTertiary = Color(0xFF80DEEA);
  static const oceanOnTertiary = Color(0xFF006064);
  static const oceanError = Color(0xFFFFB4AB);
  static const oceanOnError = Color(0xFF690005);
  static const oceanSurface = Color(0xFF0A1929);
  static const oceanOnSurface = Color(0xFFE3F2FD);
  static const oceanSurfaceVariant = Color(0xFF0D47A1);
  static const oceanOnSurfaceVariant = Color(0xFFBBDEFB);
  static const oceanOutline = Color(0xFF1976D2);
}

/// Dark mode colors with good contrast
class DarkModeColors {
  // Primary: Lighter blue for dark background
  static const darkPrimary = Color(0xFFACC7E3);
  static const darkOnPrimary = Color(0xFF1A3A52);
  static const darkPrimaryContainer = Color(0xFF3D5A73);
  static const darkOnPrimaryContainer = Color(0xFFD8E6F3);

  // Secondary
  static const darkSecondary = Color(0xFFBCC7D6);
  static const darkOnSecondary = Color(0xFF2E3842);

  // Tertiary
  static const darkTertiary = Color(0xFFB8C8D8);
  static const darkOnTertiary = Color(0xFF344451);

  // Error colors
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);

  // Surface and background: True dark mode
  static const darkSurface = Color(0xFF1A1C1E);
  static const darkOnSurface = Color(0xFFE2E8F0);
  static const darkSurfaceVariant = Color(0xFF44474E);
  static const darkOnSurfaceVariant = Color(0xFFC4C7CF);

  // Outline and shadow
  static const darkOutline = Color(0xFF8E9099);
  static const darkShadow = Color(0xFF000000);
  static const darkInversePrimary = Color(0xFF5B7C99);
}

/// Font size constants
class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 28.0;
  static const double headlineSmall = 24.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 16.0;
  static const double titleSmall = 14.0;
  static const double labelLarge = 14.0;
  static const double labelMedium = 12.0;
  static const double labelSmall = 11.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

// =============================================================================
// THEMES
// =============================================================================

/// Light theme with modern, neutral aesthetic
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
    surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
    onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
    outline: LightModeColors.lightOutline,
    shadow: LightModeColors.lightShadow,
    inversePrimary: LightModeColors.lightInversePrimary,
  ),
  brightness: Brightness.light,
  scaffoldBackgroundColor: LightModeColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: LightModeColors.lightOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: LightModeColors.lightOutline.withValues(alpha: 0.2),
        width: 1,
      ),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.light),
);

/// Dark theme with good contrast and readability
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
    surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
    onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
    outline: DarkModeColors.darkOutline,
    shadow: DarkModeColors.darkShadow,
    inversePrimary: DarkModeColors.darkInversePrimary,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkModeColors.darkSurface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: DarkModeColors.darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: DarkModeColors.darkOutline.withValues(alpha: 0.2),
        width: 1,
      ),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.dark),
);

/// Build text theme using Inter font family
TextTheme _buildTextTheme(Brightness brightness) {
  return TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w400,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
  );
}

// =============================================================================
// UNLOCKABLE THEMES (via referrals)
// =============================================================================

/// Midnight theme - deep purple dark theme (unlocked with 3 referrals)
ThemeData get midnightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: MidnightThemeColors.midnightPrimary,
    onPrimary: MidnightThemeColors.midnightOnPrimary,
    primaryContainer: MidnightThemeColors.midnightPrimaryContainer,
    onPrimaryContainer: MidnightThemeColors.midnightOnPrimaryContainer,
    secondary: MidnightThemeColors.midnightSecondary,
    onSecondary: MidnightThemeColors.midnightOnSecondary,
    tertiary: MidnightThemeColors.midnightTertiary,
    onTertiary: MidnightThemeColors.midnightOnTertiary,
    error: MidnightThemeColors.midnightError,
    onError: MidnightThemeColors.midnightOnError,
    surface: MidnightThemeColors.midnightSurface,
    onSurface: MidnightThemeColors.midnightOnSurface,
    surfaceContainerHighest: MidnightThemeColors.midnightSurfaceVariant,
    onSurfaceVariant: MidnightThemeColors.midnightOnSurfaceVariant,
    outline: MidnightThemeColors.midnightOutline,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: MidnightThemeColors.midnightSurface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: MidnightThemeColors.midnightOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: MidnightThemeColors.midnightOutline.withValues(alpha: 0.2),
        width: 1,
      ),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.dark),
);

/// Ocean theme - blue-tinted dark theme (unlocked with 5 referrals)
ThemeData get oceanTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: OceanThemeColors.oceanPrimary,
    onPrimary: OceanThemeColors.oceanOnPrimary,
    primaryContainer: OceanThemeColors.oceanPrimaryContainer,
    onPrimaryContainer: OceanThemeColors.oceanOnPrimaryContainer,
    secondary: OceanThemeColors.oceanSecondary,
    onSecondary: OceanThemeColors.oceanOnSecondary,
    tertiary: OceanThemeColors.oceanTertiary,
    onTertiary: OceanThemeColors.oceanOnTertiary,
    error: OceanThemeColors.oceanError,
    onError: OceanThemeColors.oceanOnError,
    surface: OceanThemeColors.oceanSurface,
    onSurface: OceanThemeColors.oceanOnSurface,
    surfaceContainerHighest: OceanThemeColors.oceanSurfaceVariant,
    onSurfaceVariant: OceanThemeColors.oceanOnSurfaceVariant,
    outline: OceanThemeColors.oceanOutline,
  ),
  brightness: Brightness.dark,
  scaffoldBackgroundColor: OceanThemeColors.oceanSurface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: OceanThemeColors.oceanOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: OceanThemeColors.oceanOutline.withValues(alpha: 0.2),
        width: 1,
      ),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.dark),
);

/// Available app themes
enum AppTheme {
  light,
  dark,
  midnight,
  ocean,
}

extension AppThemeExtension on AppTheme {
  String get name {
    switch (this) {
      case AppTheme.light:
        return 'Light';
      case AppTheme.dark:
        return 'Dark';
      case AppTheme.midnight:
        return 'Midnight';
      case AppTheme.ocean:
        return 'Ocean';
    }
  }

  String get description {
    switch (this) {
      case AppTheme.light:
        return 'Clean, modern light theme';
      case AppTheme.dark:
        return 'Default dark theme';
      case AppTheme.midnight:
        return 'Deep purple dark theme';
      case AppTheme.ocean:
        return 'Blue-tinted dark theme';
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

  ThemeData get themeData {
    switch (this) {
      case AppTheme.light:
        return lightTheme;
      case AppTheme.dark:
        return darkTheme;
      case AppTheme.midnight:
        return midnightTheme;
      case AppTheme.ocean:
        return oceanTheme;
    }
  }
}
