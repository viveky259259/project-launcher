import 'package:flutter_test/flutter_test.dart';
import 'package:launcher_models/launcher_models.dart';

void main() {
  group('ShipCheckItem', () {
    test('defaults to pending status', () {
      final item = ShipCheckItem(
        id: 'test-1',
        category: 'testing',
        title: 'Unit tests pass',
        mode: CheckMode.auto,
      );

      expect(item.status, CheckStatus.pending);
      expect(item.weight, 10);
    });

    test('toJson serializes correctly', () {
      final item = ShipCheckItem(
        id: 'git-1',
        category: 'git',
        title: 'No uncommitted changes',
        mode: CheckMode.auto,
        status: CheckStatus.pass,
        detail: 'Clean working tree',
      );

      final json = item.toJson();
      expect(json['id'], 'git-1');
      expect(json['status'], 'pass');
      expect(json['detail'], 'Clean working tree');
    });

    test('applyManual updates manual items only', () {
      final manualItem = ShipCheckItem(
        id: 'review-1',
        category: 'review',
        title: 'Code reviewed',
        mode: CheckMode.manual,
      );

      manualItem.applyManual({'id': 'review-1', 'status': 'pass', 'detail': 'Reviewed by team'});
      expect(manualItem.status, CheckStatus.pass);
      expect(manualItem.detail, 'Reviewed by team');
    });

    test('applyManual ignores non-manual items', () {
      final autoItem = ShipCheckItem(
        id: 'auto-1',
        category: 'build',
        title: 'Build succeeds',
        mode: CheckMode.auto,
        status: CheckStatus.fail,
      );

      autoItem.applyManual({'id': 'auto-1', 'status': 'pass'});
      expect(autoItem.status, CheckStatus.fail);
    });

    test('applyManual ignores mismatched IDs', () {
      final item = ShipCheckItem(
        id: 'item-a',
        category: 'test',
        title: 'Test',
        mode: CheckMode.manual,
      );

      item.applyManual({'id': 'item-b', 'status': 'pass'});
      expect(item.status, CheckStatus.pending);
    });
  });

  group('ShipCategory', () {
    ShipCheckItem item(CheckStatus status, {int weight = 10}) {
      return ShipCheckItem(
        id: 'i-${status.name}',
        category: 'cat',
        title: 'Item ${status.name}',
        mode: CheckMode.auto,
        status: status,
        weight: weight,
      );
    }

    test('score computes weighted percentage', () {
      final category = ShipCategory(
        id: 'test',
        title: 'Testing',
        icon: 'check',
        items: [
          item(CheckStatus.pass, weight: 20),
          item(CheckStatus.fail, weight: 20),
        ],
      );

      expect(category.score, 50);
    });

    test('score gives half credit for warnings', () {
      final category = ShipCategory(
        id: 'test',
        title: 'Testing',
        icon: 'check',
        items: [
          item(CheckStatus.warn, weight: 10),
        ],
      );

      expect(category.score, 50);
    });

    test('score excludes skipped items', () {
      final category = ShipCategory(
        id: 'test',
        title: 'Testing',
        icon: 'check',
        items: [
          item(CheckStatus.pass, weight: 10),
          item(CheckStatus.skip, weight: 10),
        ],
      );

      expect(category.score, 100);
    });

    test('score returns 100 when all items are skipped', () {
      final category = ShipCategory(
        id: 'test',
        title: 'Testing',
        icon: 'check',
        items: [item(CheckStatus.skip)],
      );

      expect(category.score, 100);
    });

    test('counts pass, fail, and applicable correctly', () {
      final category = ShipCategory(
        id: 'test',
        title: 'Testing',
        icon: 'check',
        items: [
          item(CheckStatus.pass),
          item(CheckStatus.pass),
          item(CheckStatus.fail),
          item(CheckStatus.skip),
        ],
      );

      expect(category.passCount, 2);
      expect(category.failCount, 1);
      expect(category.applicableCount, 3);
    });
  });

  group('ShipReadiness', () {
    test('overallScore averages category scores', () {
      final readiness = ShipReadiness(
        categories: [
          ShipCategory(id: 'a', title: 'A', icon: 'a', items: [
            ShipCheckItem(id: 'a1', category: 'a', title: 'A1', mode: CheckMode.auto, status: CheckStatus.pass, weight: 10),
          ]),
          ShipCategory(id: 'b', title: 'B', icon: 'b', items: [
            ShipCheckItem(id: 'b1', category: 'b', title: 'B1', mode: CheckMode.auto, status: CheckStatus.fail, weight: 10),
          ]),
        ],
        checkedAt: DateTime.now(),
      );

      expect(readiness.overallScore, 50);
    });

    test('overallScore returns 0 for empty categories', () {
      final readiness = ShipReadiness(categories: [], checkedAt: DateTime.now());
      expect(readiness.overallScore, 0);
    });

    test('criticalFailures finds high-weight failures', () {
      final readiness = ShipReadiness(
        categories: [
          ShipCategory(id: 'a', title: 'A', icon: 'a', items: [
            ShipCheckItem(id: 'a1', category: 'a', title: 'Critical', mode: CheckMode.auto, status: CheckStatus.fail, weight: 20),
            ShipCheckItem(id: 'a2', category: 'a', title: 'Minor', mode: CheckMode.auto, status: CheckStatus.fail, weight: 5),
          ]),
        ],
        checkedAt: DateTime.now(),
      );

      expect(readiness.criticalFailures, hasLength(1));
      expect(readiness.criticalFailures.first.title, 'Critical');
    });

    test('totalPass and totalFail aggregate across categories', () {
      final readiness = ShipReadiness(
        categories: [
          ShipCategory(id: 'a', title: 'A', icon: 'a', items: [
            ShipCheckItem(id: 'a1', category: 'a', title: 'A1', mode: CheckMode.auto, status: CheckStatus.pass),
            ShipCheckItem(id: 'a2', category: 'a', title: 'A2', mode: CheckMode.auto, status: CheckStatus.fail),
          ]),
          ShipCategory(id: 'b', title: 'B', icon: 'b', items: [
            ShipCheckItem(id: 'b1', category: 'b', title: 'B1', mode: CheckMode.auto, status: CheckStatus.pass),
          ]),
        ],
        checkedAt: DateTime.now(),
      );

      expect(readiness.totalPass, 2);
      expect(readiness.totalFail, 1);
      expect(readiness.totalItems, 3);
    });
  });
}
