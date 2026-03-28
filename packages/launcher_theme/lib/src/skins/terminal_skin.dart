import 'package:flutter/material.dart';
import '../app_skin.dart';
import '../app_theme.dart';
import '../app_typography.dart';

/// Terminal skin — monospace everything, green-on-black, no rounded corners.
/// ASCII aesthetic. Minimal visual chrome.
class TerminalSkin extends AppSkin {
  const TerminalSkin();

  static const _green = Color(0xFF33FF33);      // classic terminal green
  static const _dimGreen = Color(0xFF1A8C1A);
  static const _black = Color(0xFF000000);
  static const _darkBg = Color(0xFF0D0D0D);
  static const _surface = Color(0xFF111111);
  static const _border = Color(0xFF1A3A1A);      // dark green tint

  @override
  SkinMetadata get metadata => const SkinMetadata(
    id: 'terminal',
    name: 'Terminal',
    description: 'Monospace retro hacker aesthetic',
    previewColors: [_black, _surface, _green],
    requiresUnlock: true,
    unlockRewardId: 'skin_terminal',
    icon: Icons.terminal_rounded,
  );

  @override
  SkinColors get colors => const SkinColors(
    accent: _green,
    accentLight: _dimGreen,
    success: Color(0xFF33FF33),
    warning: Color(0xFFFFFF33),     // terminal yellow
    error: Color(0xFFFF3333),       // terminal red
    cardBackground: _darkBg,
    cardBackgroundHover: Color(0xFF0A1A0A), // subtle green tint on hover
    cardBorder: _border,
    cardBorderHover: Color(0xFF2A5A2A),
    cardBorderPinned: _green,
    badgeBackground: Color(0xFF0A150A),
    badgeBorder: _border,
    toolbarDivider: _border,
    statusBarBorder: _border,
  );

  @override
  SkinTypography get typography => const SkinTypography(
    primaryFontFamily: 'JetBrains Mono', // monospace everything
    monoFontFamily: 'JetBrains Mono',
    titleWeight: FontWeight.w600,
    labelWeight: FontWeight.w500,
    titleSize: 14.0,
    subtitleSize: 12.0,
    labelSize: 11.0,
    badgeSize: 10.0,
    statusBarSize: 11.0,
  );

  @override
  SkinSpacing get spacing => const SkinSpacing(
    xs: 2.0,
    sm: 4.0,
    md: 12.0,
    lg: 20.0,
    xl: 28.0,
    cardPaddingH: 12.0,
    cardPaddingV: 8.0,
    cardMarginBottom: 2.0,   // tight, like terminal lines
    toolbarPaddingH: 12.0,
    toolbarPaddingV: 8.0,
    sidebarWidth: 200.0,
    sidePanelWidth: 220.0,
    statusBarHeight: 24.0,
  );

  @override
  SkinRadius get radius => const SkinRadius(
    card: 0.0,      // no rounded corners
    gridCard: 0.0,
    badge: 0.0,
    button: 0.0,
    pill: 9999.0,   // exception: filter pills keep shape for usability
    icon: 0.0,
    panel: 0.0,
  );

  @override
  SkinCardStyle get cardStyle => const SkinCardStyle(
    listIconSize: 16.0,
    listIconContainerSize: 28.0,
    listIconRadius: 0.0,
    gridIconSize: 22.0,
    gridIconContainerSize: 40.0,
    gridIconRadius: 0.0,
    borderWidth: 1.0,
    hoverBorderWidth: 1.0,
    showBadges: false,      // text-only, no badges
    showTags: true,
    showBranchInline: true,
    showHealthDot: true,
    showActionIcons: true,
    maxVisibleTags: 2,
  );

  @override
  SkinToolbarStyle get toolbarStyle => const SkinToolbarStyle(
    buttonSize: 28.0,
    buttonIconSize: 16.0,
    buttonRadius: 0.0,
    searchHeight: 28.0,
    searchRadius: 0.0,
    filterPillPaddingH: 8.0,
    filterPillPaddingV: 4.0,
    filterPillRadius: 9999.0,
    dividerHeight: 18.0,
    dividerWidth: 1.0,
  );

  @override
  SkinAnimations get animations => const SkinAnimations(
    hoverDuration: Duration(milliseconds: 80),  // instant, like a terminal
    transitionDuration: Duration(milliseconds: 100),
    skinSwitchDuration: Duration(milliseconds: 200),
  );

  @override
  List<AppTheme> get supportedThemes => [AppTheme.dark];

  @override
  ThemeData buildThemeData(AppTheme theme) {
    final textTheme = AppTypography.buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _black,
      colorScheme: const ColorScheme.dark(
        primary: _green,
        onPrimary: _black,
        secondary: _dimGreen,
        error: Color(0xFFFF3333),
        surface: _surface,
        onSurface: _green,
        surfaceContainerHighest: Color(0xFF0A1A0A),
        onSurfaceVariant: _dimGreen,
        outline: _border,
      ),
      textTheme: textTheme,
    );
  }
}
