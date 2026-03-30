import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_theme.dart';

// ---------------------------------------------------------------------------
// Skin sub-models
// ---------------------------------------------------------------------------

/// Colors that a skin provides (beyond the MaterialApp ColorScheme).
class SkinColors {
  final Color accent;
  final Color accentLight;
  final Color success;
  final Color warning;
  final Color error;
  final Color cardBackground;
  final Color cardBackgroundHover;
  final Color cardBorder;
  final Color cardBorderHover;
  final Color cardBorderPinned;
  final Color badgeBackground;
  final Color badgeBorder;
  final Color toolbarDivider;
  final Color statusBarBorder;
  final Color glowColor; // for skins that use glow effects
  final double glowBlur; // 0 = no glow

  const SkinColors({
    required this.accent,
    required this.accentLight,
    required this.success,
    required this.warning,
    required this.error,
    required this.cardBackground,
    required this.cardBackgroundHover,
    required this.cardBorder,
    required this.cardBorderHover,
    required this.cardBorderPinned,
    required this.badgeBackground,
    required this.badgeBorder,
    required this.toolbarDivider,
    required this.statusBarBorder,
    this.glowColor = Colors.transparent,
    this.glowBlur = 0,
  });
}

/// Typography configuration for a skin.
class SkinTypography {
  final String primaryFontFamily;
  final String monoFontFamily;
  final FontWeight titleWeight;
  final FontWeight labelWeight;
  final double titleSize;
  final double subtitleSize;
  final double labelSize;
  final double badgeSize;
  final double statusBarSize;

  const SkinTypography({
    required this.primaryFontFamily,
    required this.monoFontFamily,
    required this.titleWeight,
    required this.labelWeight,
    required this.titleSize,
    required this.subtitleSize,
    required this.labelSize,
    required this.badgeSize,
    required this.statusBarSize,
  });
}

/// Spacing values for a skin.
class SkinSpacing {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double cardPaddingH;
  final double cardPaddingV;
  final double cardMarginBottom;
  final double toolbarPaddingH;
  final double toolbarPaddingV;
  final double sidebarWidth;
  final double sidePanelWidth;
  final double statusBarHeight;

  const SkinSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.cardPaddingH,
    required this.cardPaddingV,
    required this.cardMarginBottom,
    required this.toolbarPaddingH,
    required this.toolbarPaddingV,
    required this.sidebarWidth,
    required this.sidePanelWidth,
    required this.statusBarHeight,
  });
}

/// Border radius values for a skin.
class SkinRadius {
  final double card;
  final double gridCard;
  final double badge;
  final double button;
  final double pill;
  final double icon;
  final double panel;

  const SkinRadius({
    required this.card,
    required this.gridCard,
    required this.badge,
    required this.button,
    required this.pill,
    required this.icon,
    required this.panel,
  });
}

/// Card-specific visual properties.
class SkinCardStyle {
  final double listIconSize;
  final double listIconContainerSize;
  final double listIconRadius;
  final double gridIconSize;
  final double gridIconContainerSize;
  final double gridIconRadius;
  final double borderWidth;
  final double hoverBorderWidth;
  final double elevation;
  final double hoverElevation;
  final bool showBadges;
  final bool showTags;
  final bool showBranchInline;
  final bool showHealthDot;
  final bool showActionIcons;
  final int maxVisibleTags;

  const SkinCardStyle({
    required this.listIconSize,
    required this.listIconContainerSize,
    required this.listIconRadius,
    required this.gridIconSize,
    required this.gridIconContainerSize,
    required this.gridIconRadius,
    required this.borderWidth,
    required this.hoverBorderWidth,
    this.elevation = 0,
    this.hoverElevation = 0,
    this.showBadges = true,
    this.showTags = true,
    this.showBranchInline = true,
    this.showHealthDot = true,
    this.showActionIcons = true,
    this.maxVisibleTags = 2,
  });
}

/// Toolbar visual properties.
class SkinToolbarStyle {
  final double buttonSize;
  final double buttonIconSize;
  final double buttonRadius;
  final double searchHeight;
  final double searchRadius;
  final double filterPillPaddingH;
  final double filterPillPaddingV;
  final double filterPillRadius;
  final double dividerHeight;
  final double dividerWidth;

  const SkinToolbarStyle({
    required this.buttonSize,
    required this.buttonIconSize,
    required this.buttonRadius,
    required this.searchHeight,
    required this.searchRadius,
    required this.filterPillPaddingH,
    required this.filterPillPaddingV,
    required this.filterPillRadius,
    required this.dividerHeight,
    required this.dividerWidth,
  });
}

/// Animation properties for a skin.
class SkinAnimations {
  final Duration hoverDuration;
  final Duration transitionDuration;
  final Duration skinSwitchDuration;
  final Curve hoverCurve;
  final bool enableGlowPulse;
  final bool enableHoverScale;
  final double hoverScale;

  const SkinAnimations({
    required this.hoverDuration,
    required this.transitionDuration,
    required this.skinSwitchDuration,
    this.hoverCurve = Curves.easeInOut,
    this.enableGlowPulse = false,
    this.enableHoverScale = false,
    this.hoverScale = 1.0,
  });
}

/// Metadata about a skin (for the switcher UI).
class SkinMetadata {
  final String id;
  final String name;
  final String description;
  final List<Color> previewColors;
  final bool requiresUnlock;
  final String? unlockRewardId;
  final IconData icon;

  const SkinMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.previewColors,
    this.requiresUnlock = false,
    this.unlockRewardId,
    required this.icon,
  });
}

// ---------------------------------------------------------------------------
// AppSkin — the complete skin definition
// ---------------------------------------------------------------------------

/// A complete visual skin for the app.
/// Widgets read from `AppSkin.of(context)` to get all visual properties.
abstract class AppSkin {
  const AppSkin();

  SkinMetadata get metadata;
  SkinColors get colors;
  SkinTypography get typography;
  SkinSpacing get spacing;
  SkinRadius get radius;
  SkinCardStyle get cardStyle;
  SkinToolbarStyle get toolbarStyle;
  SkinAnimations get animations;

  /// The color themes this skin supports.
  List<AppTheme> get supportedThemes;

  /// Build a ThemeData for a given color theme within this skin.
  ThemeData buildThemeData(AppTheme theme);

  /// Optional: custom list card builder. Return null to use default ProjectCard.
  Widget? buildListCard(BuildContext context, dynamic project) => null;

  /// Optional: custom grid card builder. Return null to use default GridProjectCard.
  Widget? buildGridCard(BuildContext context, dynamic project) => null;

  /// Optional: custom layout override. Return null to use default list/grid.
  Widget? buildCustomLayout(BuildContext context, List<dynamic> projects) => null;

  // --- InheritedWidget access ---

  static AppSkin of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SkinProvider>();
    assert(provider != null, 'No SkinProvider found in widget tree');
    return provider!.skin;
  }

  static AppSkin? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SkinProvider>()?.skin;
  }
}

// ---------------------------------------------------------------------------
// SkinProvider — InheritedWidget
// ---------------------------------------------------------------------------

class SkinProvider extends InheritedWidget {
  final AppSkin skin;

  const SkinProvider({
    super.key,
    required this.skin,
    required super.child,
  });

  @override
  bool updateShouldNotify(SkinProvider oldWidget) {
    return skin.metadata.id != oldWidget.skin.metadata.id;
  }
}

// ---------------------------------------------------------------------------
// Skin registry
// ---------------------------------------------------------------------------

enum SkinId {
  defaultSkin,
  minimal,
  corporate,
  gaming,
  terminal,
}

extension SkinIdExtension on SkinId {
  String get key {
    switch (this) {
      case SkinId.defaultSkin: return 'default';
      case SkinId.minimal: return 'minimal';
      case SkinId.corporate: return 'corporate';
      case SkinId.gaming: return 'gaming';
      case SkinId.terminal: return 'terminal';
    }
  }
}
