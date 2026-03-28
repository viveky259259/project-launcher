import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher_theme/launcher_theme.dart';

import 'skin_contract_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSkin minimal;

  setUpAll(() {
    minimal = const MinimalSkin();
  });

  // Contract tests
  runSkinContractTests(const MinimalSkin());

  group('MinimalSkin — Specific', () {
    test('id is "minimal"', () {
      expect(minimal.metadata.id, 'minimal');
    });

    test('does not require unlock', () {
      expect(minimal.metadata.requiresUnlock, isFalse);
    });

    test('has more spacing than default', () {
      const def = DefaultSkin();
      expect(minimal.spacing.cardPaddingH, greaterThan(def.spacing.cardPaddingH));
      expect(minimal.spacing.cardPaddingV, greaterThan(def.spacing.cardPaddingV));
    });

    test('has larger card radius than default', () {
      const def = DefaultSkin();
      expect(minimal.radius.card, greaterThan(def.radius.card));
    });

    test('hides badges and tags', () {
      expect(minimal.cardStyle.showBadges, isFalse);
      expect(minimal.cardStyle.showTags, isFalse);
    });

    test('shows health dot and branch', () {
      expect(minimal.cardStyle.showHealthDot, isTrue);
      expect(minimal.cardStyle.showBranchInline, isTrue);
    });

    test('no glow effects', () {
      expect(minimal.colors.glowBlur, 0);
      expect(minimal.animations.enableGlowPulse, isFalse);
    });
  });
}
