import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:launcher_theme/launcher_theme.dart';

import 'skin_contract_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // google_fonts may fail to load in test env — that's OK, we're testing the skin model not rendering
  const skin = DefaultSkin();

  // Run all contract tests
  runSkinContractTests(skin);

  // DefaultSkin-specific tests
  group('DefaultSkin — Specific', () {
    test('id is "default"', () {
      expect(skin.metadata.id, 'default');
    });

    test('does not require unlock', () {
      expect(skin.metadata.requiresUnlock, isFalse);
    });

    test('supports all 4 color themes', () {
      expect(skin.supportedThemes, containsAll(AppTheme.values));
    });

    test('accent matches AppColors.accent', () {
      expect(skin.colors.accent, AppColors.accent);
    });

    test('status colors match AppColors', () {
      expect(skin.colors.success, AppColors.success);
      expect(skin.colors.warning, AppColors.warning);
      expect(skin.colors.error, AppColors.error);
    });

    test('uses Inter as primary font', () {
      expect(skin.typography.primaryFontFamily, 'Inter');
    });

    test('uses JetBrains Mono as mono font', () {
      expect(skin.typography.monoFontFamily, 'JetBrains Mono');
    });

    test('card radius matches AppRadius.lg', () {
      expect(skin.radius.card, AppRadius.lg);
    });

    test('no glow effect', () {
      expect(skin.colors.glowBlur, 0);
    });

    test('no hover scale', () {
      expect(skin.animations.enableHoverScale, isFalse);
    });

    test('no glow pulse', () {
      expect(skin.animations.enableGlowPulse, isFalse);
    });

    test('badges and tags are visible', () {
      expect(skin.cardStyle.showBadges, isTrue);
      expect(skin.cardStyle.showTags, isTrue);
      expect(skin.cardStyle.showBranchInline, isTrue);
      expect(skin.cardStyle.showHealthDot, isTrue);
      expect(skin.cardStyle.showActionIcons, isTrue);
    });

    testWidgets('no custom card builders (uses default widgets)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            expect(skin.buildListCard(context, null), isNull);
            expect(skin.buildGridCard(context, null), isNull);
            expect(skin.buildCustomLayout(context, []), isNull);
            return const SizedBox();
          }),
        ),
      );
    });

    test('buildThemeData for dark produces valid dark theme', () {
      final theme = skin.buildThemeData(AppTheme.dark);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.accent);
    });

    test('buildThemeData for light produces valid light theme', () {
      final theme = skin.buildThemeData(AppTheme.light);
      expect(theme.brightness, Brightness.light);
    });
  });
}
