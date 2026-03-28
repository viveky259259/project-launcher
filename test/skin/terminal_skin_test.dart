import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launcher_theme/launcher_theme.dart';

import 'skin_contract_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSkin terminal;

  setUpAll(() {
    terminal = const TerminalSkin();
  });

  // Contract tests
  runSkinContractTests(const TerminalSkin());

  group('TerminalSkin — Specific', () {
    test('id is "terminal"', () {
      expect(terminal.metadata.id, 'terminal');
    });

    test('requires unlock (premium)', () {
      expect(terminal.metadata.requiresUnlock, isTrue);
      expect(terminal.metadata.unlockRewardId, isNotNull);
    });

    test('uses monospace for both fonts', () {
      expect(terminal.typography.primaryFontFamily, 'JetBrains Mono');
      expect(terminal.typography.monoFontFamily, 'JetBrains Mono');
    });

    test('all radius values are zero (no rounded corners)', () {
      expect(terminal.radius.card, 0);
      expect(terminal.radius.gridCard, 0);
      expect(terminal.radius.badge, 0);
      expect(terminal.radius.button, 0);
      expect(terminal.radius.icon, 0);
      expect(terminal.radius.panel, 0);
    });

    test('pill radius is still full (pills are an exception)', () {
      // Even terminal skin keeps pill shape for filter pills
      expect(terminal.radius.pill, greaterThan(0));
    });

    test('accent is green (classic terminal)', () {
      expect(terminal.colors.accent.g, greaterThan(0.5));
    });

    test('no glow, no hover scale', () {
      expect(terminal.animations.enableGlowPulse, isFalse);
      expect(terminal.animations.enableHoverScale, isFalse);
    });

    test('hides badges (minimal text-only display)', () {
      expect(terminal.cardStyle.showBadges, isFalse);
    });

    test('only supports dark themes', () {
      for (final theme in terminal.supportedThemes) {
        final data = terminal.buildThemeData(theme);
        expect(data.brightness, Brightness.dark);
      }
    });
  });
}
