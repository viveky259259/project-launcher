import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher_theme/launcher_theme.dart';

import 'skin_contract_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSkin projekta;

  setUpAll(() {
    projekta = const ProjektaSkin();
  });

  // Contract tests
  runSkinContractTests(const ProjektaSkin());

  group('ProjektaSkin — Specific', () {
    test('id is "projekta"', () {
      expect(projekta.metadata.id, 'projekta');
    });

    test('requires unlock', () {
      expect(projekta.metadata.requiresUnlock, isTrue);
      expect(projekta.metadata.unlockRewardId, 'skin_projekta');
    });

    test('accent is muted green', () {
      expect(projekta.colors.accent, const Color(0xFF4A6741));
    });

    test('accentLight is steel blue', () {
      expect(projekta.colors.accentLight, const Color(0xFF7C9CB4));
    });

    test('supports light and dark themes', () {
      expect(projekta.supportedThemes, contains(AppTheme.light));
      expect(projekta.supportedThemes, contains(AppTheme.dark));
    });

    test('uses Inter font', () {
      expect(projekta.typography.primaryFontFamily, 'Inter');
    });

    test('has moderate card radius', () {
      expect(projekta.radius.card, 10.0);
      expect(projekta.radius.gridCard, 12.0);
    });

    test('shows badges and tags', () {
      expect(projekta.cardStyle.showBadges, isTrue);
      expect(projekta.cardStyle.showTags, isTrue);
    });

    test('has subtle card elevation', () {
      expect(projekta.cardStyle.elevation, greaterThan(0));
      expect(projekta.cardStyle.hoverElevation,
          greaterThan(projekta.cardStyle.elevation));
    });

    test('no glow effects', () {
      expect(projekta.colors.glowBlur, 0);
      expect(projekta.animations.enableGlowPulse, isFalse);
    });
  });
}
