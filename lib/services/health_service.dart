import 'dart:convert';
import 'dart:io';
import '../models/health_score.dart';
import 'git_service.dart';

class HealthService {
  static const String _cacheFileName = 'health_cache.json';

  static String get _cacheFilePath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.project_launcher/$_cacheFileName';
  }

  static Future<void> _ensureDirectoryExists() async {
    final home = Platform.environment['HOME'] ?? '';
    final dir = Directory('$home/.project_launcher');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Load cached health scores from disk
  static Future<Map<String, CachedHealthScore>> loadCache() async {
    try {
      await _ensureDirectoryExists();
      final file = File(_cacheFilePath);
      if (!await file.exists()) {
        return {};
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        return {};
      }
      final Map<String, dynamic> jsonMap = json.decode(content);
      return jsonMap.map((key, value) =>
          MapEntry(key, CachedHealthScore.fromJson(value as Map<String, dynamic>)));
    } catch (e) {
      return {};
    }
  }

  /// Save health cache to disk
  static Future<void> saveCache(Map<String, CachedHealthScore> cache) async {
    try {
      await _ensureDirectoryExists();
      final file = File(_cacheFilePath);
      final jsonMap = cache.map((key, value) => MapEntry(key, value.toJson()));
      await file.writeAsString(json.encode(jsonMap));
    } catch (e) {
      // Ignore cache write errors
    }
  }

  /// Get health score for a project (from cache or calculate fresh)
  static Future<CachedHealthScore> getHealthScore(String projectPath, {bool forceRefresh = false}) async {
    final cache = await loadCache();

    // Check if we have a valid cached score
    if (!forceRefresh && cache.containsKey(projectPath)) {
      final cached = cache[projectPath]!;
      if (!cached.isExpired) {
        return cached;
      }
    }

    // Calculate fresh health score
    final details = await _calculateHealthScore(projectPath);
    final staleness = await _calculateStaleness(projectPath);

    final newCached = CachedHealthScore(
      projectPath: projectPath,
      details: details,
      staleness: staleness,
      cachedAt: DateTime.now(),
    );

    // Update cache
    cache[projectPath] = newCached;
    await saveCache(cache);

    return newCached;
  }

  /// Calculate health score for a project
  static Future<HealthScoreDetails> _calculateHealthScore(String projectPath) async {
    int gitScore = 0;
    int depsScore = 0;
    int testsScore = 0;

    // Git scoring (40 points max)
    bool hasRecentCommits = false;
    bool noUncommittedChanges = false;
    bool noUnpushedCommits = false;
    DateTime? lastCommitDate;

    final isGitRepo = await GitService.isGitRepository(projectPath);
    if (isGitRepo) {
      // Recent commits (within 30 days) - 15 points
      lastCommitDate = await GitService.getLastCommitDate(projectPath);
      if (lastCommitDate != null) {
        final daysSinceCommit = DateTime.now().difference(lastCommitDate).inDays;
        if (daysSinceCommit < 30) {
          hasRecentCommits = true;
          gitScore += 15;
        } else if (daysSinceCommit < 90) {
          gitScore += 10;
        } else if (daysSinceCommit < 180) {
          gitScore += 5;
        }
      }

      // No uncommitted changes - 15 points
      final hasChanges = await GitService.hasUncommittedChanges(projectPath);
      if (!hasChanges) {
        noUncommittedChanges = true;
        gitScore += 15;
      }

      // No unpushed commits - 10 points
      final unpushedCount = await GitService.getUnpushedCommitCount(projectPath);
      if (unpushedCount == 0) {
        noUnpushedCommits = true;
        gitScore += 10;
      }
    }

    // Dependencies scoring (30 points max)
    bool hasDependencyFile = false;
    bool hasLockFile = false;
    String? dependencyFileType;

    final depChecks = [
      {'dep': 'pubspec.yaml', 'lock': 'pubspec.lock', 'type': 'Flutter/Dart'},
      {'dep': 'package.json', 'lock': 'package-lock.json', 'type': 'Node.js'},
      {'dep': 'package.json', 'lock': 'yarn.lock', 'type': 'Node.js (Yarn)'},
      {'dep': 'requirements.txt', 'lock': 'requirements.lock', 'type': 'Python'},
      {'dep': 'Pipfile', 'lock': 'Pipfile.lock', 'type': 'Python (Pipenv)'},
      {'dep': 'pyproject.toml', 'lock': 'poetry.lock', 'type': 'Python (Poetry)'},
      {'dep': 'Cargo.toml', 'lock': 'Cargo.lock', 'type': 'Rust'},
      {'dep': 'go.mod', 'lock': 'go.sum', 'type': 'Go'},
      {'dep': 'Gemfile', 'lock': 'Gemfile.lock', 'type': 'Ruby'},
      {'dep': 'composer.json', 'lock': 'composer.lock', 'type': 'PHP'},
      {'dep': 'build.gradle', 'lock': 'gradle.lockfile', 'type': 'Gradle'},
      {'dep': 'pom.xml', 'lock': null, 'type': 'Maven'},
    ];

    for (final check in depChecks) {
      final depFile = File('$projectPath/${check['dep']}');
      if (await depFile.exists()) {
        hasDependencyFile = true;
        dependencyFileType = check['type'] as String;
        depsScore += 20;

        if (check['lock'] != null) {
          final lockFile = File('$projectPath/${check['lock']}');
          if (await lockFile.exists()) {
            hasLockFile = true;
            depsScore += 10;
          }
        } else {
          // No lock file expected, full points
          hasLockFile = true;
          depsScore += 10;
        }
        break;
      }
    }

    // Tests scoring (30 points max)
    bool hasTestFolder = false;
    bool hasTestFiles = false;

    final testFolders = ['test', 'tests', 'spec', 'specs', '__tests__', 'test_suite'];
    for (final folder in testFolders) {
      final testDir = Directory('$projectPath/$folder');
      if (await testDir.exists()) {
        hasTestFolder = true;
        testsScore += 15;

        // Check if there are actual test files
        try {
          await for (final entity in testDir.list(recursive: true)) {
            if (entity is File) {
              final name = entity.path.split('/').last.toLowerCase();
              if (name.contains('test') || name.contains('spec')) {
                hasTestFiles = true;
                testsScore += 15;
                break;
              }
            }
          }
        } catch (e) {
          // Permission denied, skip
        }
        break;
      }
    }

    // Also check for test files in lib/src directories
    if (!hasTestFiles) {
      final srcDirs = ['lib', 'src', 'app'];
      for (final dir in srcDirs) {
        final srcDir = Directory('$projectPath/$dir');
        if (await srcDir.exists()) {
          try {
            await for (final entity in srcDir.list(recursive: true)) {
              if (entity is File) {
                final name = entity.path.split('/').last.toLowerCase();
                if (name.contains('_test.') || name.contains('.test.') || name.contains('_spec.')) {
                  hasTestFiles = true;
                  testsScore += 15;
                  break;
                }
              }
            }
            if (hasTestFiles) break;
          } catch (e) {
            // Permission denied, skip
          }
        }
      }
    }

    return HealthScoreDetails(
      gitScore: gitScore,
      depsScore: depsScore,
      testsScore: testsScore,
      hasRecentCommits: hasRecentCommits,
      noUncommittedChanges: noUncommittedChanges,
      noUnpushedCommits: noUnpushedCommits,
      lastCommitDate: lastCommitDate,
      hasDependencyFile: hasDependencyFile,
      hasLockFile: hasLockFile,
      dependencyFileType: dependencyFileType,
      hasTestFolder: hasTestFolder,
      hasTestFiles: hasTestFiles,
    );
  }

  /// Calculate staleness level based on last activity
  static Future<StalenessLevel> _calculateStaleness(String projectPath) async {
    final lastCommitDate = await GitService.getLastCommitDate(projectPath);

    if (lastCommitDate == null) {
      // No git history, check file modification times
      final dir = Directory(projectPath);
      DateTime? latestMod;
      try {
        await for (final entity in dir.list(recursive: false)) {
          if (entity is File) {
            final stat = await entity.stat();
            if (latestMod == null || stat.modified.isAfter(latestMod)) {
              latestMod = stat.modified;
            }
          }
        }
      } catch (e) {
        // Ignore errors
      }

      if (latestMod == null) {
        return StalenessLevel.abandoned;
      }

      final days = DateTime.now().difference(latestMod).inDays;
      return StalenessLevelExtension.fromDays(days);
    }

    final days = DateTime.now().difference(lastCommitDate).inDays;
    return StalenessLevelExtension.fromDays(days);
  }

  /// Get health scores for multiple projects (batched)
  static Future<Map<String, CachedHealthScore>> getHealthScores(
    List<String> projectPaths, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = <String, CachedHealthScore>{};

    for (var i = 0; i < projectPaths.length; i++) {
      final path = projectPaths[i];
      results[path] = await getHealthScore(path);
      onProgress?.call(i + 1, projectPaths.length);
    }

    return results;
  }

  /// Invalidate cache for a specific project
  static Future<void> invalidateCache(String projectPath) async {
    final cache = await loadCache();
    cache.remove(projectPath);
    await saveCache(cache);
  }

  /// Clear all cached health scores
  static Future<void> clearCache() async {
    try {
      final file = File(_cacheFilePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore errors
    }
  }
}
