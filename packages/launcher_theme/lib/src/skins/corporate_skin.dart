import 'package:flutter/material.dart';
import '../app_skin.dart';
import '../app_colors.dart';
import '../app_theme.dart';
import '../app_typography.dart';

/// Corporate skin — Microsoft/Office style.
/// Sharp corners, dense layout, system font, muted blue accent.
class CorporateSkin extends AppSkin {
  const CorporateSkin();

  static const _blue = Color(0xFF4A90D9);     // Office blue
  static const _darkBg = Color(0xFF1E1E1E);   // VS Code dark
  static const _surface = Color(0xFF252526);   // VS Code surface
  static const _border = Color(0xFF3C3C3C);    // VS Code border
  static const _text = Color(0xFFCCCCCC);      // VS Code text
  static const _textDim = Color(0xFF858585);   // VS Code dimmed

  @override
  SkinMetadata get metadata => const SkinMetadata(
    id: 'corporate',
    name: 'Corporate',
    description: 'Microsoft Office-inspired dense layout',
    previewColors: [_darkBg, _surface, _blue],
    requiresUnlock: true,
    unlockRewardId: 'skin_corporate',
    icon: Icons.business_rounded,
  );

  @override
  SkinColors get colors => const SkinColors(
    accent: _blue,
    accentLight: Color(0xFF3A7AC8),
    success: Color(0xFF4EC95D),     // Teams green
    warning: Color(0xFFFFB900),     // Office amber
    error: Color(0xFFD13438),       // Office red
    cardBackground: _surface,
    cardBackgroundHover: Color(0xFF2D2D2D),
    cardBorder: _border,
    cardBorderHover: Color(0xFF505050),
    cardBorderPinned: _blue,
    badgeBackground: Color(0xFF333333),
    badgeBorder: _border,
    toolbarDivider: _border,
    statusBarBorder: Color(0xFF007ACC), // VS Code status bar blue
  );

  @override
  SkinTypography get typography => const SkinTypography(
    primaryFontFamily: '.SF Pro Text', // macOS system font
    monoFontFamily: 'JetBrains Mono',
    titleWeight: FontWeight.w600,
    labelWeight: FontWeight.w500,
    titleSize: 14.0,    // smaller, denser
    subtitleSize: 12.0,
    labelSize: 11.0,
    badgeSize: 10.0,
    statusBarSize: 11.0,
  );

  @override
  SkinSpacing get spacing => const SkinSpacing(
    xs: 2.0,   // tighter
    sm: 4.0,
    md: 10.0,
    lg: 16.0,
    xl: 24.0,
    cardPaddingH: 12.0,  // tighter than default 16
    cardPaddingV: 8.0,   // tighter than default 12
    cardMarginBottom: 2.0, // tight rows
    toolbarPaddingH: 12.0,
    toolbarPaddingV: 8.0,
    sidebarWidth: 200.0,
    sidePanelWidth: 220.0,
    statusBarHeight: 24.0, // shorter
  );

  @override
  SkinRadius get radius => const SkinRadius(
    card: 3.0,      // sharp
    gridCard: 4.0,   // sharp
    badge: 2.0,
    button: 2.0,
    pill: 3.0,       // not fully rounded, more rectangular
    icon: 3.0,
    panel: 4.0,
  );

  @override
  SkinCardStyle get cardStyle => const SkinCardStyle(
    listIconSize: 16.0,     // smaller
    listIconContainerSize: 30.0,
    listIconRadius: 3.0,
    gridIconSize: 22.0,
    gridIconContainerSize: 42.0,
    gridIconRadius: 4.0,
    borderWidth: 1.0,
    hoverBorderWidth: 1.0,
    showBadges: true,
    showTags: true,
    showBranchInline: true,
    showHealthDot: true,
    showActionIcons: true,
    maxVisibleTags: 3, // show more since rows are compact
  );

  @override
  SkinToolbarStyle get toolbarStyle => const SkinToolbarStyle(
    buttonSize: 28.0,      // compact
    buttonIconSize: 16.0,
    buttonRadius: 2.0,
    searchHeight: 28.0,    // compact
    searchRadius: 2.0,
    filterPillPaddingH: 8.0,
    filterPillPaddingV: 4.0,
    filterPillRadius: 3.0, // rectangular pills
    dividerHeight: 18.0,
    dividerWidth: 1.0,
  );

  @override
  SkinAnimations get animations => const SkinAnimations(
    hoverDuration: Duration(milliseconds: 100), // snappy
    transitionDuration: Duration(milliseconds: 150),
    skinSwitchDuration: Duration(milliseconds: 250),
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
        scaffoldBackgroundColor: const Color(0xFFF3F3F3),
        colorScheme: const ColorScheme.light(
          primary: _blue,
          secondary: Color(0xFF6B6B6B),
          error: Color(0xFFD13438),
          surface: Colors.white,
          onSurface: Color(0xFF1E1E1E),
          surfaceContainerHighest: Color(0xFFE8E8E8),
          onSurfaceVariant: Color(0xFF616161),
          outline: Color(0xFFD0D0D0),
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
        primary: _blue,
        onPrimary: Colors.white,
        secondary: _textDim,
        error: Color(0xFFD13438),
        surface: _surface,
        onSurface: _text,
        surfaceContainerHighest: Color(0xFF2D2D2D),
        onSurfaceVariant: _textDim,
        outline: _border,
      ),
      textTheme: textTheme,
    );
  }
}
