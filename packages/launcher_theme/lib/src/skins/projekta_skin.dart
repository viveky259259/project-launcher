import 'package:flutter/material.dart';
import '../app_skin.dart';
import '../app_theme.dart';

/// Projekta skin — clean project-management aesthetic.
/// Muted green accent, steel blue secondary, generous whitespace,
/// moderate radius, subtle card elevation. Supports light + dark.
class ProjektaSkin extends AppSkin {
  const ProjektaSkin();

  // -- Palette --
  static const _green = Color(0xFF4A6741);       // accent green
  static const _greenLight = Color(0xFF81C784);   // dark-mode success
  static const _blue = Color(0xFF7C9CB4);         // steel blue secondary
  static const _error = Color(0xFFC44D4D);        // muted red
  static const _warning = Color(0xFFE5A94D);      // warm amber

  // Dark palette
  static const _darkBg = Color(0xFF121212);
  static const _darkSurface = Color(0xFF1A1A1A);
  static const _darkBorder = Color(0xFF2D2D2D);
  static const _darkText = Color(0xFFF5F5F5);
  static const _darkTextDim = Color(0xFFA0A0A0);

  // Light palette
  static const _lightBg = Color(0xFFFFFFFF);
  static const _lightSurface = Color(0xFFF5F5F5);
  static const _lightBorder = Color(0xFFE5E5E5);
  static const _lightText = Color(0xFF1A1A1A);
  static const _lightTextDim = Color(0xFF666666);

  @override
  SkinMetadata get metadata => const SkinMetadata(
    id: 'projekta',
    name: 'Projekta',
    description: 'Clean project-management style with green accent',
    previewColors: [_darkBg, _darkSurface, _green],
    requiresUnlock: true,
    unlockRewardId: 'skin_projekta',
    icon: Icons.inventory_2_rounded,
  );

  @override
  SkinColors get colors => const SkinColors(
    accent: _green,
    accentLight: _blue,
    success: _greenLight,
    warning: _warning,
    error: _error,
    cardBackground: _darkSurface,
    cardBackgroundHover: Color(0xFF222222),
    cardBorder: _darkBorder,
    cardBorderHover: Color(0xFF3D3D3D),
    cardBorderPinned: _green,
    badgeBackground: Color(0xFF222222),
    badgeBorder: _darkBorder,
    toolbarDivider: _darkBorder,
    statusBarBorder: _darkBorder,
  );

  @override
  SkinTypography get typography => const SkinTypography(
    primaryFontFamily: 'Inter',
    monoFontFamily: 'JetBrains Mono',
    titleWeight: FontWeight.w600,
    labelWeight: FontWeight.w500,
    titleSize: 15.0,
    subtitleSize: 13.0,
    labelSize: 12.0,
    badgeSize: 10.0,
    statusBarSize: 11.0,
  );

  @override
  SkinSpacing get spacing => const SkinSpacing(
    xs: 4.0,
    sm: 8.0,
    md: 16.0,
    lg: 24.0,
    xl: 40.0,
    cardPaddingH: 18.0,
    cardPaddingV: 14.0,
    cardMarginBottom: 6.0,
    toolbarPaddingH: 16.0,
    toolbarPaddingV: 12.0,
    sidebarWidth: 220.0,
    sidePanelWidth: 240.0,
    statusBarHeight: 26.0,
  );

  @override
  SkinRadius get radius => const SkinRadius(
    card: 10.0,
    gridCard: 12.0,
    badge: 6.0,
    button: 8.0,
    pill: 9999.0,
    icon: 10.0,
    panel: 12.0,
  );

  @override
  SkinCardStyle get cardStyle => const SkinCardStyle(
    listIconSize: 18.0,
    listIconContainerSize: 36.0,
    listIconRadius: 10.0,
    gridIconSize: 24.0,
    gridIconContainerSize: 48.0,
    gridIconRadius: 12.0,
    borderWidth: 1.0,
    hoverBorderWidth: 1.0,
    elevation: 1.0,
    hoverElevation: 3.0,
    showBadges: true,
    showTags: true,
    showBranchInline: true,
    showHealthDot: true,
    showActionIcons: true,
    maxVisibleTags: 2,
  );

  @override
  SkinToolbarStyle get toolbarStyle => const SkinToolbarStyle(
    buttonSize: 32.0,
    buttonIconSize: 16.0,
    buttonRadius: 8.0,
    searchHeight: 34.0,
    searchRadius: 10.0,
    filterPillPaddingH: 12.0,
    filterPillPaddingV: 6.0,
    filterPillRadius: 9999.0,
    dividerHeight: 20.0,
    dividerWidth: 1.0,
  );

  @override
  SkinAnimations get animations => const SkinAnimations(
    hoverDuration: Duration(milliseconds: 150),
    transitionDuration: Duration(milliseconds: 200),
    skinSwitchDuration: Duration(milliseconds: 300),
  );

  @override
  List<AppTheme> get supportedThemes => [AppTheme.dark, AppTheme.light];

  @override
  ThemeData buildThemeData(AppTheme theme) {
    final textTheme = AppTypography.buildTextTheme();

    if (theme == AppTheme.light) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _lightBg,
        colorScheme: const ColorScheme.light(
          primary: _green,
          onPrimary: Colors.white,
          secondary: _blue,
          onSecondary: Colors.white,
          error: _error,
          onError: Colors.white,
          surface: _lightSurface,
          onSurface: _lightText,
          surfaceContainerHighest: Color(0xFFEEEEEE),
          onSurfaceVariant: _lightTextDim,
          outline: _lightBorder,
        ),
        textTheme: textTheme,
      );
    }

    // Dark (default)
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      colorScheme: const ColorScheme.dark(
        primary: _green,
        onPrimary: Colors.white,
        secondary: _blue,
        onSecondary: Colors.white,
        error: _error,
        onError: _darkText,
        surface: _darkSurface,
        onSurface: _darkText,
        surfaceContainerHighest: Color(0xFF222222),
        onSurfaceVariant: _darkTextDim,
        outline: _darkBorder,
      ),
      textTheme: textTheme,
    );
  }
}
