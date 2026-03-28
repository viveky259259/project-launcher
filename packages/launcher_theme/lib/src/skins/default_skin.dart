import 'package:flutter/material.dart';
import '../app_skin.dart';
import '../app_colors.dart';
import '../app_theme.dart';

/// The default skin — matches the current app appearance exactly.
/// This is the baseline against which all other skins are compared.
class DefaultSkin extends AppSkin {
  const DefaultSkin();

  @override
  SkinMetadata get metadata => const SkinMetadata(
    id: 'default',
    name: 'Default',
    description: 'The classic Project Launcher look',
    previewColors: [Color(0xFF000000), Color(0xFF111111), AppColors.accent],
    requiresUnlock: false,
    icon: Icons.palette_outlined,
  );

  @override
  SkinColors get colors => const SkinColors(
    accent: AppColors.accent,
    accentLight: AppColors.accentLight,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    cardBackground: DarkColors.surface,
    cardBackgroundHover: DarkColors.surfaceContainer,
    cardBorder: DarkColors.outline,
    cardBorderHover: DarkColors.outline,
    cardBorderPinned: AppColors.accent,
    badgeBackground: DarkColors.surfaceContainer,
    badgeBorder: DarkColors.outline,
    toolbarDivider: DarkColors.outline,
    statusBarBorder: DarkColors.outline,
  );

  @override
  SkinTypography get typography => const SkinTypography(
    primaryFontFamily: 'Inter',
    monoFontFamily: 'JetBrains Mono',
    titleWeight: FontWeight.w600,
    labelWeight: FontWeight.w600,
    titleSize: 16.0,
    subtitleSize: 12.0,
    labelSize: 11.0,
    badgeSize: 10.0,
    statusBarSize: 10.0,
  );

  @override
  SkinSpacing get spacing => const SkinSpacing(
    xs: 4.0,
    sm: 8.0,
    md: 16.0,
    lg: 24.0,
    xl: 32.0,
    cardPaddingH: 16.0,
    cardPaddingV: 12.0,
    cardMarginBottom: 6.0,
    toolbarPaddingH: 16.0,
    toolbarPaddingV: 12.0,
    sidebarWidth: 220.0,
    sidePanelWidth: 240.0,
    statusBarHeight: 28.0,
  );

  @override
  SkinRadius get radius => const SkinRadius(
    card: 8.0,
    gridCard: 16.0,
    badge: 4.0,
    button: 4.0,
    pill: 9999.0,
    icon: 10.0,
    panel: 12.0,
  );

  @override
  SkinCardStyle get cardStyle => const SkinCardStyle(
    listIconSize: 20.0,
    listIconContainerSize: 38.0,
    listIconRadius: 10.0,
    gridIconSize: 28.0,
    gridIconContainerSize: 56.0,
    gridIconRadius: 14.0,
    borderWidth: 1.0,
    hoverBorderWidth: 1.0,
    elevation: 0.0,
    hoverElevation: 0.0,
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
    searchHeight: 36.0,
    searchRadius: 8.0,
    filterPillPaddingH: 10.0,
    filterPillPaddingV: 6.0,
    filterPillRadius: 9999.0,
    dividerHeight: 24.0,
    dividerWidth: 1.0,
  );

  @override
  SkinAnimations get animations => const SkinAnimations(
    hoverDuration: Duration(milliseconds: 150),
    transitionDuration: Duration(milliseconds: 200),
    skinSwitchDuration: Duration(milliseconds: 300),
  );

  @override
  List<AppTheme> get supportedThemes => AppTheme.values.toList();

  @override
  ThemeData buildThemeData(AppTheme theme) => theme.themeData;
}
