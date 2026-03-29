import 'package:flutter_test/flutter_test.dart';
import 'package:project_launcher/services/dashboard_config.dart';

void main() {
  group('DashboardTile', () {
    test('fromJson creates a tile with all fields', () {
      final json = {
        'id': 'tile-1',
        'type': 'healthOverview',
        'size': 'large',
        'order': 2,
        'visible': false,
      };

      final tile = DashboardTile.fromJson(json);

      expect(tile.id, 'tile-1');
      expect(tile.type, DashboardTileType.healthOverview);
      expect(tile.size, TileSize.large);
      expect(tile.order, 2);
      expect(tile.visible, false);
    });

    test('fromJson uses defaults for missing fields', () {
      final json = {
        'id': 'tile-2',
        'type': 'recentProjects',
      };

      final tile = DashboardTile.fromJson(json);

      expect(tile.size, TileSize.medium);
      expect(tile.order, 0);
      expect(tile.visible, true);
    });

    test('fromJson handles unknown type gracefully', () {
      final json = {
        'id': 'tile-3',
        'type': 'nonExistentType',
        'order': 0,
      };

      final tile = DashboardTile.fromJson(json);
      expect(tile.type, DashboardTileType.recentProjects);
    });

    test('toJson roundtrips correctly', () {
      final original = DashboardTile(
        id: 'tile-rt',
        type: DashboardTileType.quickActions,
        size: TileSize.small,
        order: 5,
        visible: false,
      );

      final json = original.toJson();
      final restored = DashboardTile.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.size, original.size);
      expect(restored.order, original.order);
      expect(restored.visible, original.visible);
    });

    test('copyWith updates specified fields', () {
      const tile = DashboardTile(
        id: 'tile-cw',
        type: DashboardTileType.pinnedProjects,
        order: 0,
      );

      final updated = tile.copyWith(size: TileSize.large, visible: false);

      expect(updated.size, TileSize.large);
      expect(updated.visible, false);
      expect(updated.id, tile.id);
      expect(updated.type, tile.type);
      expect(updated.order, tile.order);
    });

    test('label returns human-readable string', () {
      const tile = DashboardTile(
        id: 'tile-label',
        type: DashboardTileType.healthOverview,
        order: 0,
      );

      expect(tile.label, 'Health Overview');
    });

    test('all tile types have non-empty labels and descriptions', () {
      for (final type in DashboardTileType.values) {
        final tile = DashboardTile(id: 'test', type: type, order: 0);
        expect(tile.label, isNotEmpty, reason: '$type should have a label');
        expect(tile.description, isNotEmpty, reason: '$type should have a description');
      }
    });
  });
}
