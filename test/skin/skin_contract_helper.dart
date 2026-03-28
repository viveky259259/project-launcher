import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:launcher_theme/launcher_theme.dart';

/// Runs contract tests against any AppSkin implementation.
/// Every skin MUST pass these tests to be valid.
void runSkinContractTests(AppSkin skin) {
  group('${skin.metadata.name} — Contract Tests', () {
    // --- Metadata ---
    group('Metadata', () {
      test('has non-empty id', () {
        expect(skin.metadata.id, isNotEmpty);
      });

      test('has non-empty name', () {
        expect(skin.metadata.name, isNotEmpty);
      });

      test('has non-empty description', () {
        expect(skin.metadata.description, isNotEmpty);
      });

      test('has preview colors', () {
        expect(skin.metadata.previewColors, isNotEmpty);
        expect(skin.metadata.previewColors.length, greaterThanOrEqualTo(2));
      });

      test('has valid icon', () {
        expect(skin.metadata.icon, isNotNull);
      });

      test('premium skins have unlockRewardId', () {
        if (skin.metadata.requiresUnlock) {
          expect(skin.metadata.unlockRewardId, isNotNull);
          expect(skin.metadata.unlockRewardId, isNotEmpty);
        }
      });
    });

    // --- Colors ---
    group('Colors', () {
      test('accent colors are non-transparent', () {
        expect(skin.colors.accent.a, greaterThan(0));
        expect(skin.colors.accentLight.a, greaterThan(0));
      });

      test('status colors are non-transparent', () {
        expect(skin.colors.success.a, greaterThan(0));
        expect(skin.colors.warning.a, greaterThan(0));
        expect(skin.colors.error.a, greaterThan(0));
      });

      test('card colors are defined', () {
        expect(skin.colors.cardBackground, isNotNull);
        expect(skin.colors.cardBackgroundHover, isNotNull);
        expect(skin.colors.cardBorder, isNotNull);
        expect(skin.colors.cardBorderHover, isNotNull);
        expect(skin.colors.cardBorderPinned, isNotNull);
      });

      test('badge and toolbar colors are defined', () {
        expect(skin.colors.badgeBackground, isNotNull);
        expect(skin.colors.badgeBorder, isNotNull);
        expect(skin.colors.toolbarDivider, isNotNull);
        expect(skin.colors.statusBarBorder, isNotNull);
      });

      test('glow blur is non-negative', () {
        expect(skin.colors.glowBlur, greaterThanOrEqualTo(0));
      });
    });

    // --- Typography ---
    group('Typography', () {
      test('font families are non-empty', () {
        expect(skin.typography.primaryFontFamily, isNotEmpty);
        expect(skin.typography.monoFontFamily, isNotEmpty);
      });

      test('font sizes are positive', () {
        expect(skin.typography.titleSize, greaterThan(0));
        expect(skin.typography.subtitleSize, greaterThan(0));
        expect(skin.typography.labelSize, greaterThan(0));
        expect(skin.typography.badgeSize, greaterThan(0));
        expect(skin.typography.statusBarSize, greaterThan(0));
      });

      test('title size >= subtitle size >= label size', () {
        expect(skin.typography.titleSize,
            greaterThanOrEqualTo(skin.typography.subtitleSize));
        expect(skin.typography.subtitleSize,
            greaterThanOrEqualTo(skin.typography.labelSize));
      });
    });

    // --- Spacing ---
    group('Spacing', () {
      test('all spacing values are positive', () {
        expect(skin.spacing.xs, greaterThan(0));
        expect(skin.spacing.sm, greaterThan(0));
        expect(skin.spacing.md, greaterThan(0));
        expect(skin.spacing.lg, greaterThan(0));
        expect(skin.spacing.xl, greaterThan(0));
      });

      test('spacing values are ordered xs < sm < md < lg < xl', () {
        expect(skin.spacing.xs, lessThan(skin.spacing.sm));
        expect(skin.spacing.sm, lessThan(skin.spacing.md));
        expect(skin.spacing.md, lessThan(skin.spacing.lg));
        expect(skin.spacing.lg, lessThan(skin.spacing.xl));
      });

      test('card padding is positive', () {
        expect(skin.spacing.cardPaddingH, greaterThan(0));
        expect(skin.spacing.cardPaddingV, greaterThan(0));
      });

      test('card margin is non-negative', () {
        expect(skin.spacing.cardMarginBottom, greaterThanOrEqualTo(0));
      });

      test('layout dimensions are positive', () {
        expect(skin.spacing.sidebarWidth, greaterThan(0));
        expect(skin.spacing.sidePanelWidth, greaterThan(0));
        expect(skin.spacing.statusBarHeight, greaterThan(0));
      });
    });

    // --- Radius ---
    group('Radius', () {
      test('all radius values are non-negative', () {
        expect(skin.radius.card, greaterThanOrEqualTo(0));
        expect(skin.radius.gridCard, greaterThanOrEqualTo(0));
        expect(skin.radius.badge, greaterThanOrEqualTo(0));
        expect(skin.radius.button, greaterThanOrEqualTo(0));
        expect(skin.radius.pill, greaterThanOrEqualTo(0));
        expect(skin.radius.icon, greaterThanOrEqualTo(0));
        expect(skin.radius.panel, greaterThanOrEqualTo(0));
      });
    });

    // --- Card Style ---
    group('Card Style', () {
      test('icon sizes are positive', () {
        expect(skin.cardStyle.listIconSize, greaterThan(0));
        expect(skin.cardStyle.listIconContainerSize, greaterThan(0));
        expect(skin.cardStyle.gridIconSize, greaterThan(0));
        expect(skin.cardStyle.gridIconContainerSize, greaterThan(0));
      });

      test('icon container >= icon size', () {
        expect(skin.cardStyle.listIconContainerSize,
            greaterThanOrEqualTo(skin.cardStyle.listIconSize));
        expect(skin.cardStyle.gridIconContainerSize,
            greaterThanOrEqualTo(skin.cardStyle.gridIconSize));
      });

      test('border widths are non-negative', () {
        expect(skin.cardStyle.borderWidth, greaterThanOrEqualTo(0));
        expect(skin.cardStyle.hoverBorderWidth, greaterThanOrEqualTo(0));
      });

      test('elevation values are non-negative', () {
        expect(skin.cardStyle.elevation, greaterThanOrEqualTo(0));
        expect(skin.cardStyle.hoverElevation, greaterThanOrEqualTo(0));
      });

      test('maxVisibleTags is non-negative', () {
        expect(skin.cardStyle.maxVisibleTags, greaterThanOrEqualTo(0));
      });
    });

    // --- Toolbar Style ---
    group('Toolbar Style', () {
      test('button dimensions are positive', () {
        expect(skin.toolbarStyle.buttonSize, greaterThan(0));
        expect(skin.toolbarStyle.buttonIconSize, greaterThan(0));
      });

      test('button icon fits inside button', () {
        expect(skin.toolbarStyle.buttonSize,
            greaterThanOrEqualTo(skin.toolbarStyle.buttonIconSize));
      });

      test('search dimensions are positive', () {
        expect(skin.toolbarStyle.searchHeight, greaterThan(0));
        expect(skin.toolbarStyle.searchRadius, greaterThanOrEqualTo(0));
      });

      test('filter pill padding is positive', () {
        expect(skin.toolbarStyle.filterPillPaddingH, greaterThan(0));
        expect(skin.toolbarStyle.filterPillPaddingV, greaterThan(0));
      });
    });

    // --- Animations ---
    group('Animations', () {
      test('durations are positive', () {
        expect(skin.animations.hoverDuration.inMilliseconds, greaterThan(0));
        expect(
            skin.animations.transitionDuration.inMilliseconds, greaterThan(0));
        expect(
            skin.animations.skinSwitchDuration.inMilliseconds, greaterThan(0));
      });

      test('hover scale is positive if enabled', () {
        if (skin.animations.enableHoverScale) {
          expect(skin.animations.hoverScale, greaterThan(0));
        }
      });
    });

    // --- Themes ---
    group('Themes', () {
      test('supports at least one theme', () {
        expect(skin.supportedThemes, isNotEmpty);
      });

      testWidgets('buildThemeData returns valid ThemeData for each supported theme',
          (tester) async {
        for (final theme in skin.supportedThemes) {
          final themeData = skin.buildThemeData(theme);
          expect(themeData, isNotNull);
          expect(themeData.colorScheme, isNotNull);
          expect(themeData.textTheme, isNotNull);
        }
        // Pump to flush async google_fonts font loading
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      });
    });
  });
}
