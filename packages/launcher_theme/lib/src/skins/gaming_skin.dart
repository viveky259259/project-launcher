import 'package:flutter/material.dart';
import '../app_skin.dart';
import '../app_theme.dart';
import '../app_typography.dart';

/// Gaming skin — PUBG/HUD neon aesthetic.
/// Dark background, neon glow borders, angular feel, bold typography.
class GamingSkin extends AppSkin {
  const GamingSkin();

  static const _neonCyan = Color(0xFF00FFFF);
  static const _neonGreen = Color(0xFF39FF14);
  static const _neonPink = Color(0xFFFF00FF);
  static const _darkBg = Color(0xFF0A0A0F);
  static const _surface = Color(0xFF12121A);
  static const _border = Color(0xFF1A1A2E);

  @override
  SkinMetadata get metadata => const SkinMetadata(
    id: 'gaming',
    name: 'Gaming',
    description: 'Neon HUD with glow effects',
    previewColors: [_darkBg, _surface, _neonCyan],
    requiresUnlock: true,
    unlockRewardId: 'skin_gaming',
    icon: Icons.sports_esports_rounded,
  );

  @override
  SkinColors get colors => const SkinColors(
    accent: _neonCyan,
    accentLight: Color(0xFF00CCCC),
    success: _neonGreen,
    warning: Color(0xFFFFE100),   // electric yellow
    error: Color(0xFFFF3333),     // neon red
    cardBackground: _surface,
    cardBackgroundHover: Color(0xFF1A1A28),
    cardBorder: _border,
    cardBorderHover: Color(0xFF2A2A40),
    cardBorderPinned: _neonCyan,
    badgeBackground: Color(0xFF15152A),
    badgeBorder: Color(0xFF252540),
    toolbarDivider: _border,
    statusBarBorder: _border,
    glowColor: _neonCyan,
    glowBlur: 8.0,
  );

  @override
  SkinTypography get typography => const SkinTypography(
    primaryFontFamily: 'Inter',  // bold weights give the gaming feel
    monoFontFamily: 'JetBrains Mono',
    titleWeight: FontWeight.w700,    // bold
    labelWeight: FontWeight.w700,
    titleSize: 15.0,
    subtitleSize: 11.0,
    labelSize: 10.0,
    badgeSize: 9.0,
    statusBarSize: 10.0,
  );

  @override
  SkinSpacing get spacing => const SkinSpacing(
    xs: 4.0,
    sm: 8.0,
    md: 14.0,
    lg: 22.0,
    xl: 30.0,
    cardPaddingH: 14.0,
    cardPaddingV: 12.0,
    cardMarginBottom: 6.0,
    toolbarPaddingH: 14.0,
    toolbarPaddingV: 10.0,
    sidebarWidth: 220.0,
    sidePanelWidth: 240.0,
    statusBarHeight: 28.0,
  );

  @override
  SkinRadius get radius => const SkinRadius(
    card: 4.0,       // angular
    gridCard: 6.0,
    badge: 2.0,
    button: 4.0,
    pill: 4.0,       // not fully rounded, more angular
    icon: 6.0,
    panel: 6.0,
  );

  @override
  SkinCardStyle get cardStyle => const SkinCardStyle(
    listIconSize: 20.0,
    listIconContainerSize: 40.0,
    listIconRadius: 6.0,
    gridIconSize: 28.0,
    gridIconContainerSize: 56.0,
    gridIconRadius: 8.0,
    borderWidth: 1.0,
    hoverBorderWidth: 2.0,  // thicker on hover
    elevation: 0.0,
    hoverElevation: 4.0,    // cards lift
    showBadges: true,
    showTags: true,
    showBranchInline: true,
    showHealthDot: true,
    showActionIcons: true,
    maxVisibleTags: 2,
  );

  @override
  SkinToolbarStyle get toolbarStyle => const SkinToolbarStyle(
    buttonSize: 34.0,
    buttonIconSize: 18.0,
    buttonRadius: 4.0,
    searchHeight: 34.0,
    searchRadius: 4.0,
    filterPillPaddingH: 10.0,
    filterPillPaddingV: 5.0,
    filterPillRadius: 4.0,
    dividerHeight: 22.0,
    dividerWidth: 1.0,
  );

  @override
  SkinAnimations get animations => const SkinAnimations(
    hoverDuration: Duration(milliseconds: 120),
    transitionDuration: Duration(milliseconds: 200),
    skinSwitchDuration: Duration(milliseconds: 350),
    enableGlowPulse: true,
    enableHoverScale: true,
    hoverScale: 1.02,
  );

  @override
  List<AppTheme> get supportedThemes => [AppTheme.dark, AppTheme.midnight];

  @override
  ThemeData buildThemeData(AppTheme theme) {
    final textTheme = AppTypography.buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      colorScheme: const ColorScheme.dark(
        primary: _neonCyan,
        onPrimary: Colors.black,
        secondary: _neonGreen,
        error: Color(0xFFFF3333),
        surface: _surface,
        onSurface: Color(0xFFE0E0FF),
        surfaceContainerHighest: Color(0xFF1A1A28),
        onSurfaceVariant: Color(0xFF8888AA),
        outline: _border,
      ),
      textTheme: textTheme,
    );
  }
}
