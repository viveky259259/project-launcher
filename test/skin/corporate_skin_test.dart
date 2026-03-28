import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher_theme/launcher_theme.dart';

import 'skin_contract_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSkin corporate;

  setUpAll(() {
    corporate = const CorporateSkin();
  });

  // Contract tests
  runSkinContractTests(const CorporateSkin());

  group('CorporateSkin — Specific', () {
    test('id is "corporate"', () {
      expect(corporate.metadata.id, 'corporate');
    });

    test('requires unlock (premium)', () {
      expect(corporate.metadata.requiresUnlock, isTrue);
      expect(corporate.metadata.unlockRewardId, isNotNull);
    });

    test('has smaller radius than default (sharper corners)', () {
      const def = DefaultSkin();
      expect(corporate.radius.card, lessThan(def.radius.card));
      expect(corporate.radius.gridCard, lessThan(def.radius.gridCard));
    });

    test('has tighter spacing than default (denser)', () {
      const def = DefaultSkin();
      expect(corporate.spacing.cardPaddingV, lessThanOrEqualTo(def.spacing.cardPaddingV));
      expect(corporate.spacing.cardMarginBottom, lessThanOrEqualTo(def.spacing.cardMarginBottom));
    });

    test('uses system font', () {
      // SF Pro or system-ui or Segoe UI
      expect(corporate.typography.primaryFontFamily, isNotEmpty);
      expect(corporate.typography.primaryFontFamily, isNot('Inter'));
    });

    test('shows all info (badges, tags, branch)', () {
      expect(corporate.cardStyle.showBadges, isTrue);
      expect(corporate.cardStyle.showTags, isTrue);
      expect(corporate.cardStyle.showBranchInline, isTrue);
    });

    test('accent is muted blue', () {
      // Corporate blue should be in the blue range
      expect(corporate.colors.accent.b, greaterThan(0.4));
    });
  });
}
