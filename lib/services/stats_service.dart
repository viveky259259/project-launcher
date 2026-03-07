import 'dart:convert';
import 'dart:io';
import 'git_service.dart';
import 'health_service.dart';
import 'project_storage.dart';

/// Aggregated stats for year-in-review feature
class YearInReviewStats {
  final int totalProjects;
  final int totalCommits;
  final String? mostActiveProject;
  final int mostActiveProjectCommits;
  final Map<String, int> monthlyActivity;
  final int activeProjectsCount;
  final DateTime generatedAt;

  /// Per-project commit counts (project name -> commits), sorted by commits desc
  final Map<String, int> projectCommits;

  /// Language distribution (language name -> project count)
  final Map<String, int> languageDistribution;

  /// Estimated coding hours (commits * ~25 min average)
  final int estimatedCodingHours;

  /// Longest daily commit streak in the year
  final int longestStreak;

  const YearInReviewStats({
    required this.totalProjects,
    required this.totalCommits,
    this.mostActiveProject,
    this.mostActiveProjectCommits = 0,
    required this.monthlyActivity,
    required this.activeProjectsCount,
    required this.generatedAt,
    this.projectCommits = const {},
    this.languageDistribution = const {},
    this.estimatedCodingHours = 0,
    this.longestStreak = 0,
  });

  factory YearInReviewStats.fromJson(Map<String, dynamic> json) {
    return YearInReviewStats(
      totalProjects: json['totalProjects'] as int? ?? 0,
      totalCommits: json['totalCommits'] as int? ?? 0,
      mostActiveProject: json['mostActiveProject'] as String?,
      mostActiveProjectCommits: json['mostActiveProjectCommits'] as int? ?? 0,
      monthlyActivity: (json['monthlyActivity'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      activeProjectsCount: json['activeProjectsCount'] as int? ?? 0,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      projectCommits: (json['projectCommits'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      languageDistribution: (json['languageDistribution'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      estimatedCodingHours: json['estimatedCodingHours'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalProjects': totalProjects,
      'totalCommits': totalCommits,
      'mostActiveProject': mostActiveProject,
      'mostActiveProjectCommits': mostActiveProjectCommits,
      'monthlyActivity': monthlyActivity,
      'activeProjectsCount': activeProjectsCount,
      'generatedAt': generatedAt.toIso8601String(),
      'projectCommits': projectCommits,
      'languageDistribution': languageDistribution,
      'estimatedCodingHours': estimatedCodingHours,
      'longestStreak': longestStreak,
    };
  }
}

class StatsService {
  static const String _cacheFileName = 'stats_cache.json';

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

  /// Load cached stats from disk
  static Future<YearInReviewStats?> loadCachedStats() async {
    try {
      await _ensureDirectoryExists();
      final file = File(_cacheFilePath);
      if (!await file.exists()) {
        return null;
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        return null;
      }
      return YearInReviewStats.fromJson(json.decode(content));
    } catch (e) {
      return null;
    }
  }

  /// Save stats cache to disk
  static Future<void> saveCachedStats(YearInReviewStats stats) async {
    try {
      await _ensureDirectoryExists();
      final file = File(_cacheFilePath);
      await file.writeAsString(json.encode(stats.toJson()));
    } catch (e) {
      // Ignore cache write errors
    }
  }

  /// Generate year-in-review stats
  static Future<YearInReviewStats> generateStats({
    void Function(String currentProject, int current, int total)? onProgress,
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = await loadCachedStats();
      if (cached != null) {
        // Cache valid for 1 hour
        if (DateTime.now().difference(cached.generatedAt).inHours < 1) {
          return cached;
        }
      }
    }

    final projects = await ProjectStorage.loadProjects();
    int totalCommits = 0;
    String? mostActiveProject;
    int mostActiveCommits = 0;
    final monthlyActivity = <String, int>{};
    int activeProjectsCount = 0;
    final projectCommits = <String, int>{};
    final languageCounts = <String, int>{};

    // Load health cache for language detection
    final healthCache = await HealthService.loadCache();

    for (var i = 0; i < projects.length; i++) {
      final project = projects[i];
      onProgress?.call(project.name, i + 1, projects.length);

      final isGitRepo = await GitService.isGitRepository(project.path);
      if (!isGitRepo) continue;

      // Get yearly commit count
      final yearlyCommits = await GitService.getYearlyCommitCount(project.path);
      totalCommits += yearlyCommits;

      if (yearlyCommits > 0) {
        activeProjectsCount++;
        projectCommits[project.name] = yearlyCommits;
      }

      // Track most active project
      if (yearlyCommits > mostActiveCommits) {
        mostActiveCommits = yearlyCommits;
        mostActiveProject = project.name;
      }

      // Get monthly breakdown
      final monthlyCommits = await GitService.getMonthlyCommitCounts(project.path);
      for (final entry in monthlyCommits.entries) {
        monthlyActivity[entry.key] = (monthlyActivity[entry.key] ?? 0) + entry.value;
      }

      // Detect language from health cache
      final cached = healthCache[project.path];
      if (cached != null && cached.details.dependencyFileType != null) {
        final lang = _depTypeToLanguage(cached.details.dependencyFileType!);
        if (lang.isNotEmpty) {
          languageCounts[lang] = (languageCounts[lang] ?? 0) + 1;
        }
      }
    }

    // Sort projectCommits by value descending
    final sortedProjectCommits = Map.fromEntries(
      projectCommits.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );

    // Sort language distribution by count descending
    final sortedLanguages = Map.fromEntries(
      languageCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );

    // Estimate coding hours (~25 min per commit)
    final estimatedHours = (totalCommits * 25 / 60).round();

    // Estimate longest streak from monthly data
    // (Rough: best month's commits / 30 gives avg daily, streak ~ that * factor)
    final bestMonth = monthlyActivity.values.isEmpty ? 0 : monthlyActivity.values.reduce((a, b) => a > b ? a : b);
    final estimatedStreak = bestMonth > 0 ? (bestMonth * 0.7).round().clamp(1, 365) : 0;

    final stats = YearInReviewStats(
      totalProjects: projects.length,
      totalCommits: totalCommits,
      mostActiveProject: mostActiveProject,
      mostActiveProjectCommits: mostActiveCommits,
      monthlyActivity: monthlyActivity,
      activeProjectsCount: activeProjectsCount,
      generatedAt: DateTime.now(),
      projectCommits: sortedProjectCommits,
      languageDistribution: sortedLanguages,
      estimatedCodingHours: estimatedHours,
      longestStreak: estimatedStreak,
    );

    await saveCachedStats(stats);
    return stats;
  }

  static String _depTypeToLanguage(String depType) {
    switch (depType) {
      case 'pubspec.yaml': return 'Flutter';
      case 'package.json': return 'NodeJS';
      case 'requirements.txt':
      case 'setup.py':
      case 'pyproject.toml': return 'Python';
      case 'Cargo.toml': return 'Rust';
      case 'go.mod': return 'Go';
      case 'Gemfile': return 'Ruby';
      case 'composer.json': return 'PHP';
      case 'build.gradle':
      case 'build.gradle.kts': return 'Kotlin';
      case 'pom.xml': return 'Java';
      default: return '';
    }
  }

  /// Clear stats cache
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

  /// Get stats summary text for sharing
  static String getShareableText(YearInReviewStats stats) {
    final lines = <String>[
      'My Project Launcher Year in Review',
      '',
      '${stats.totalProjects} projects managed',
      '${stats.totalCommits} commits this year',
      '${stats.activeProjectsCount} active projects',
    ];

    if (stats.mostActiveProject != null) {
      lines.add('');
      lines.add('Most active: ${stats.mostActiveProject}');
      lines.add('${stats.mostActiveProjectCommits} commits');
    }

    lines.add('');
    lines.add('Tracked with Project Launcher');

    return lines.join('\n');
  }
}
