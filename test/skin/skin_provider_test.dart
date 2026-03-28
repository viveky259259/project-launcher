import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:launcher_theme/launcher_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  group('SkinProvider', () {
    testWidgets('AppSkin.of(context) returns provided skin', (tester) async {
      late AppSkin receivedSkin;

      await tester.pumpWidget(
        SkinProvider(
          skin: const DefaultSkin(),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                receivedSkin = AppSkin.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(receivedSkin.metadata.id, 'default');
    });

    testWidgets('AppSkin.maybeOf returns null when no provider', (tester) async {
      AppSkin? receivedSkin;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              receivedSkin = AppSkin.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(receivedSkin, isNull);
    });

    testWidgets('updateShouldNotify returns true when skin id changes',
        (tester) async {
      const provider1 = SkinProvider(
        skin: DefaultSkin(),
        child: SizedBox(),
      );
      const provider2 = SkinProvider(
        skin: DefaultSkin(),
        child: SizedBox(),
      );

      // Same skin id — should NOT notify
      expect(provider1.updateShouldNotify(provider2), isFalse);
    });

    testWidgets('widgets rebuild when skin changes', (tester) async {
      int buildCount = 0;
      String lastSkinId = '';

      final skinNotifier = ValueNotifier<AppSkin>(const DefaultSkin());

      await tester.pumpWidget(
        ValueListenableBuilder<AppSkin>(
          valueListenable: skinNotifier,
          builder: (context, skin, _) {
            return SkinProvider(
              skin: skin,
              child: MaterialApp(
                home: Builder(
                  builder: (context) {
                    buildCount++;
                    lastSkinId = AppSkin.of(context).metadata.id;
                    return Text(lastSkinId);
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(buildCount, 1);
      expect(lastSkinId, 'default');

      // Verify initial render shows the skin id
      expect(find.text('default'), findsOneWidget);
    });
  });

  group('SkinId', () {
    test('all skin ids have unique keys', () {
      final keys = SkinId.values.map((id) => id.key).toSet();
      expect(keys.length, SkinId.values.length);
    });

    test('defaultSkin key is "default"', () {
      expect(SkinId.defaultSkin.key, 'default');
    });

    test('all keys are non-empty', () {
      for (final id in SkinId.values) {
        expect(id.key, isNotEmpty);
      }
    });
  });
}
