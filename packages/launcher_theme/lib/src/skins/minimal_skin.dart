import 'package:flutter/material.dart';
import '../app_skin.dart';
import '../app_colors.dart';
import '../app_theme.dart';

/// Minimal skin — clean lines, lots of whitespace, fewer elements.
/// Hides badges and tags. Shows only name, health dot, branch.
class MinimalSkin extends AppSkin {
  const MinimalSkin();

  @override
  SkinMetadata get metadata => const SkinMetadata(
    id: 'minimal',
    name: 'Minimal',
    description: 'Clean and airy with extra whitespace',
    previewColors: [Color(0xFF0A0A0A), Color(0xFF141414), Color(0xFF8B9DAF)],
    requiresUnlock: false,
    icon: Icons.spa_outlined,
  );

  @override
  SkinColors get colors => const SkinColors(
    accent: Color(0xFF8B9DAF), // muted slate blue
    accentLight: Color(0xFF6B8299),
    success: Color(0xFF6EE7B7), // soft green
    warning: Color(0xFFFCD34D), // soft amber
    error: Color(0xFFFCA5A5), // soft red
    cardBackground: Color(0xFF111111),
    cardBackgroundHover: Color(0xFF1A1A1A),
    cardBorder: Color(0xFF1F1F1F),
    cardBorderHover: Color(0xFF333333),
    cardBorderPinned: Color(0xFF8B9DAF),
    badgeBackground: Color(0xFF1A1A1A),
    badgeBorder: Color(0xFF262626),
    toolbarDivider: Color(0xFF1F1F1F),
    statusBarBorder: Color(0xFF1F1F1F),
  );

  @override
  SkinTypography get typography => const SkinTypography(
    primaryFontFamily: 'Inter',
    monoFontFamily: 'JetBrains Mono',
    titleWeight: FontWeight.w500, // lighter than default
    labelWeight: FontWeight.w500,
    titleSize: 15.0,
    subtitleSize: 12.0,
    labelSize: 11.0,
    badgeSize: 10.0,
    statusBarSize: 10.0,
  );

  @override
  SkinSpacing get spacing => const SkinSpacing(
    xs: 6.0,  // more than default 4
    sm: 10.0, // more than default 8
    md: 20.0, // more than default 16
    lg: 28.0, // more than default 24
    xl: 40.0, // more than default 32
    cardPaddingH: 20.0,  // more than default 16
    cardPaddingV: 16.0,  // more than default 12
    cardMarginBottom: 8.0, // more than default 6
    toolbarPaddingH: 20.0,
    toolbarPaddingV: 14.0,
    sidebarWidth: 200.0, // narrower
    sidePanelWidth: 220.0, // narrower
    statusBarHeight: 28.0,
  );

  @override
  SkinRadius get radius => const SkinRadius(
    card: 14.0,    // larger than default 8
    gridCard: 20.0, // larger than default 16
    badge: 6.0,
    button: 8.0,
    pill: 9999.0,
    icon: 12.0,
    panel: 16.0,
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
    showBadges: false,   // key difference: no badges
    showTags: false,     // key difference: no tags
    showBranchInline: true,
    showHealthDot: true,
    showActionIcons: true,
    maxVisibleTags: 0,
  );

  @override
  SkinToolbarStyle get toolbarStyle => const SkinToolbarStyle(
    buttonSize: 32.0,
    buttonIconSize: 16.0,
    buttonRadius: 8.0,
    searchHeight: 36.0,
    searchRadius: 12.0,
    filterPillPaddingH: 12.0,
    filterPillPaddingV: 6.0,
    filterPillRadius: 9999.0,
    dividerHeight: 20.0,
    dividerWidth: 1.0,
  );

  @override
  SkinAnimations get animations => const SkinAnimations(
    hoverDuration: Duration(milliseconds: 200), // slightly slower, more graceful
    transitionDuration: Duration(milliseconds: 250),
    skinSwitchDuration: Duration(milliseconds: 400),
  );

  @override
  List<AppTheme> get supportedThemes => AppTheme.values.toList();

  @override
  ThemeData buildThemeData(AppTheme theme) => theme.themeData;
}
