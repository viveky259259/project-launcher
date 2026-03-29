import 'package:flutter_test/flutter_test.dart';
import 'package:launcher_models/launcher_models.dart';

void main() {
  group('StalenessLevel', () {
    test('fromDays returns correct levels', () {
      expect(StalenessLevelExtension.fromDays(0), StalenessLevel.fresh);
      expect(StalenessLevelExtension.fromDays(29), StalenessLevel.fresh);
      expect(StalenessLevelExtension.fromDays(30), StalenessLevel.warning);
      expect(StalenessLevelExtension.fromDays(89), StalenessLevel.warning);
      expect(StalenessLevelExtension.fromDays(90), StalenessLevel.stale);
      expect(StalenessLevelExtension.fromDays(179), StalenessLevel.stale);
      expect(StalenessLevelExtension.fromDays(180), StalenessLevel.abandoned);
      expect(StalenessLevelExtension.fromDays(999), StalenessLevel.abandoned);
    });

    test('labels are human-readable', () {
      expect(StalenessLevel.fresh.label, 'Fresh');
      expect(StalenessLevel.warning.label, 'Getting Stale');
      expect(StalenessLevel.stale.label, 'Stale');
      expect(StalenessLevel.abandoned.label, 'Abandoned');
    });

    test('daysThreshold returns correct boundaries', () {
      expect(StalenessLevel.fresh.daysThreshold, 30);
      expect(StalenessLevel.warning.daysThreshold, 90);
      expect(StalenessLevel.stale.daysThreshold, 180);
      expect(StalenessLevel.abandoned.daysThreshold, 365);
    });
  });

  group('HealthScoreDetails', () {
    test('totalScore sums all categories', () {
      const details = HealthScoreDetails(
        gitScore: 35,
        depsScore: 25,
        testsScore: 20,
      );
      expect(details.totalScore, 80);
    });

    test('category returns healthy for score >= 80', () {
      const details = HealthScoreDetails(
        gitScore: 40,
        depsScore: 30,
        testsScore: 10,
      );
      expect(details.totalScore, 80);
      expect(details.category, HealthCategory.healthy);
    });

    test('category returns needsAttention for score 50-79', () {
      const details = HealthScoreDetails(
        gitScore: 30,
        depsScore: 15,
        testsScore: 10,
      );
      expect(details.totalScore, 55);
      expect(details.category, HealthCategory.needsAttention);
    });

    test('category returns critical for score < 50', () {
      const details = HealthScoreDetails(
        gitScore: 10,
        depsScore: 10,
        testsScore: 0,
      );
      expect(details.totalScore, 20);
      expect(details.category, HealthCategory.critical);
    });

    test('fromJson/toJson roundtrips', () {
      final original = HealthScoreDetails(
        gitScore: 35,
        depsScore: 25,
        testsScore: 20,
        hasRecentCommits: true,
        noUncommittedChanges: true,
        hasDependencyFile: true,
        hasLockFile: true,
        dependencyFileType: 'pubspec.yaml',
        hasTestFolder: true,
        lastCommitDate: DateTime(2026, 3, 28),
      );

      final json = original.toJson();
      final restored = HealthScoreDetails.fromJson(json);

      expect(restored.gitScore, original.gitScore);
      expect(restored.depsScore, original.depsScore);
      expect(restored.testsScore, original.testsScore);
      expect(restored.totalScore, original.totalScore);
      expect(restored.hasRecentCommits, true);
      expect(restored.hasDependencyFile, true);
      expect(restored.dependencyFileType, 'pubspec.yaml');
      expect(restored.hasTestFolder, true);
    });

    test('fromJson handles missing fields gracefully', () {
      final details = HealthScoreDetails.fromJson({});

      expect(details.gitScore, 0);
      expect(details.depsScore, 0);
      expect(details.testsScore, 0);
      expect(details.hasRecentCommits, false);
      expect(details.lastCommitDate, isNull);
    });
  });
}
