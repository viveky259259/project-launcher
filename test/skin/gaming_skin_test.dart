import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher_theme/launcher_theme.dart';

import 'skin_contract_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSkin gaming;

  setUpAll(() {
    gaming = const GamingSkin();
  });

  // Contract tests
  runSkinContractTests(const GamingSkin());

  group('GamingSkin — Specific', () {
    test('id is "gaming"', () {
      expect(gaming.metadata.id, 'gaming');
    });

    test('requires unlock (premium)', () {
      expect(gaming.metadata.requiresUnlock, isTrue);
      expect(gaming.metadata.unlockRewardId, isNotNull);
    });

    test('has glow effect', () {
      expect(gaming.colors.glowBlur, greaterThan(0));
      expect(gaming.colors.glowColor, isNot(Colors.transparent));
    });

    test('enables glow pulse animation', () {
      expect(gaming.animations.enableGlowPulse, isTrue);
    });

    test('uses bold/condensed font', () {
      expect(gaming.typography.primaryFontFamily, isNotEmpty);
      expect(gaming.typography.titleWeight, FontWeight.w700);
    });

    test('has hover elevation (cards lift on hover)', () {
      expect(gaming.cardStyle.hoverElevation, greaterThan(0));
    });

    test('only supports dark themes', () {
      for (final theme in gaming.supportedThemes) {
        final data = gaming.buildThemeData(theme);
        expect(data.brightness, Brightness.dark);
      }
    });

    test('accent is neon cyan or green', () {
      // Neon accent should be bright
      final accent = gaming.colors.accent;
      expect(accent.g + accent.b, greaterThan(1.0));
    });
  });
}
