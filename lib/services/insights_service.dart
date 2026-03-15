import '../models/health_score.dart';
import 'health_service.dart';
import 'git_service.dart';
import 'project_storage.dart';
import 'project_type_detector.dart';

/// Priority level for insights
enum InsightPriority { critical, warning, info, tip }

/// Category of insight
enum InsightCategory { git, health, activity, techDebt, growth }

/// A single actionable insight about the user's projects
class Insight {
  final String title;
  final String description;
  final InsightPriority priority;
  final InsightCategory category;
  final String? projectName;
  final String? projectPath;
  final String? actionLabel;

  const Insight({
    required this.title,
    required this.description,
    required this.priority,
    required this.category,
    this.projectName,
    this.projectPath,
    this.actionLabel,
  });
}

/// Summary stats for the insights dashboard
class InsightsSummary {
  final int totalProjects;
  final int healthyCount;
  final int attentionCount;
  final int criticalCount;
  final int staleCount;
  final int unpushedCount;
  final int uncommittedCount;
  final int noTestsCount;
  final int noGitCount;
  final double avgHealthScore;
  final String? mostNeglectedProject;
  final int mostNeglectedDays;

  const InsightsSummary({
    required this.totalProjects,
    required this.healthyCount,
    required this.attentionCount,
    required this.criticalCount,
    required this.staleCount,
    required this.unpushedCount,
    required this.uncommittedCount,
    required this.noTestsCount,
    required this.noGitCount,
    required this.avgHealthScore,
    this.mostNeglectedProject,
    this.mostNeglectedDays = 0,
  });
}

class InsightsService {
  /// Generate all insights from current project data
  static Future<List<Insight>> generateInsights({
    void Function(int current, int total)? onProgress,
  }) async {
    final projects = await ProjectStorage.loadProjects();
    final healthCache = await HealthService.loadCache();
    final insights = <Insight>[];

    // Ensure we have health data
    for (var i = 0; i < projects.length; i++) {
      onProgress?.call(i + 1, projects.length);
      if (!healthCache.containsKey(projects[i].path)) {
        await HealthService.getHealthScore(projects[i].path);
      }
    }

    // Reload with any newly computed scores
    final scores = await HealthService.loadCache();

    // ── Critical: Unpushed commits ──
    for (final project in projects) {
      final isGit = await GitService.isGitRepository(project.path);
      if (!isGit) continue;
      final unpushed = await GitService.getUnpushedCommitCount(project.path);
      if (unpushed > 0) {
        insights.add(Insight(
          title: '$unpushed unpushed commit${unpushed > 1 ? 's' : ''}',
          description:
              '${project.name} has work that hasn\'t been pushed to remote. '
              'Push to avoid data loss.',
          priority: unpushed >= 5
              ? InsightPriority.critical
              : InsightPriority.warning,
          category: InsightCategory.git,
          projectName: project.name,
          projectPath: project.path,
          actionLabel: 'Open in Terminal',
        ));
      }
    }

    // ── Critical: Uncommitted changes ──
    for (final project in projects) {
      final isGit = await GitService.isGitRepository(project.path);
      if (!isGit) continue;
      final hasChanges = await GitService.hasUncommittedChanges(project.path);
      if (hasChanges) {
        final cached = scores[project.path];
        final days = cached?.details.lastCommitDate != null
            ? DateTime.now().difference(cached!.details.lastCommitDate!).inDays
            : 0;
        if (days > 7) {
          insights.add(Insight(
            title: 'Uncommitted changes for ${days}d',
            description:
                '${project.name} has uncommitted changes sitting for $days days. '
                'Commit or stash them to keep your history clean.',
            priority: InsightPriority.warning,
            category: InsightCategory.git,
            projectName: project.name,
            projectPath: project.path,
            actionLabel: 'Open in Terminal',
          ));
        }
      }
    }

    // ── Warning: Stale projects ──
    for (final project in projects) {
      final cached = scores[project.path];
      if (cached == null) continue;
      if (cached.staleness == StalenessLevel.stale ||
          cached.staleness == StalenessLevel.abandoned) {
        final days = cached.details.lastCommitDate != null
            ? DateTime.now().difference(cached.details.lastCommitDate!).inDays
            : 999;
        insights.add(Insight(
          title:
              '${project.name} is ${cached.staleness == StalenessLevel.abandoned ? "abandoned" : "going stale"}',
          description: days < 999
              ? 'No commits in $days days. Consider archiving it or setting a reminder to revisit.'
              : 'No git history found. Is this project still active?',
          priority: cached.staleness == StalenessLevel.abandoned
              ? InsightPriority.info
              : InsightPriority.warning,
          category: InsightCategory.activity,
          projectName: project.name,
          projectPath: project.path,
        ));
      }
    }

    // ── Tech Debt: No tests ──
    final noTestProjects = <String>[];
    for (final project in projects) {
      final cached = scores[project.path];
      if (cached == null) continue;
      if (!cached.details.hasTestFolder && !cached.details.hasTestFiles) {
        noTestProjects.add(project.name);
      }
    }
    if (noTestProjects.isNotEmpty) {
      insights.add(Insight(
        title:
            '${noTestProjects.length} project${noTestProjects.length > 1 ? 's' : ''} have no tests',
        description: noTestProjects.length <= 3
            ? '${noTestProjects.join(", ")} — adding even basic tests improves maintainability.'
            : '${noTestProjects.take(3).join(", ")} and ${noTestProjects.length - 3} more. '
                'Start with the most critical ones.',
        priority: InsightPriority.warning,
        category: InsightCategory.techDebt,
      ));
    }

    // ── Tech Debt: No lock file ──
    final noLockProjects = <String>[];
    for (final project in projects) {
      final cached = scores[project.path];
      if (cached == null) continue;
      if (cached.details.hasDependencyFile && !cached.details.hasLockFile) {
        noLockProjects.add(project.name);
      }
    }
    if (noLockProjects.isNotEmpty) {
      insights.add(Insight(
        title:
            '${noLockProjects.length} project${noLockProjects.length > 1 ? 's' : ''} missing lock files',
        description:
            '${noLockProjects.take(3).join(", ")}${noLockProjects.length > 3 ? " and more" : ""} — '
            'lock files ensure reproducible builds across machines.',
        priority: InsightPriority.warning,
        category: InsightCategory.techDebt,
      ));
    }

    // ── Info: No git ──
    final noGitProjects = <String>[];
    for (final project in projects) {
      final isGit = await GitService.isGitRepository(project.path);
      if (!isGit) noGitProjects.add(project.name);
    }
    if (noGitProjects.isNotEmpty) {
      insights.add(Insight(
        title:
            '${noGitProjects.length} project${noGitProjects.length > 1 ? 's' : ''} not using git',
        description:
            '${noGitProjects.take(3).join(", ")}${noGitProjects.length > 3 ? " and more" : ""} — '
            'initialize git to track changes and enable health scoring.',
        priority: InsightPriority.info,
        category: InsightCategory.git,
      ));
    }

    // ── Tip: Health score distribution ──
    final scoredProjects = projects
        .where((p) => scores.containsKey(p.path))
        .map((p) => scores[p.path]!.details.totalScore)
        .toList();
    if (scoredProjects.isNotEmpty) {
      final avg =
          scoredProjects.reduce((a, b) => a + b) / scoredProjects.length;
      final criticalCount =
          scoredProjects.where((s) => s < 50).length;
      if (avg < 50) {
        insights.add(Insight(
          title: 'Average health is ${avg.round()}/100',
          description:
              'Most of your projects need attention. Focus on the critical ones first — '
              'push unpushed commits, add missing tests, and update dependencies.',
          priority: InsightPriority.warning,
          category: InsightCategory.health,
        ));
      } else if (criticalCount == 0 && avg >= 80) {
        insights.add(Insight(
          title: 'All projects are healthy!',
          description:
              'Average health: ${avg.round()}/100. Great job maintaining your projects.',
          priority: InsightPriority.tip,
          category: InsightCategory.health,
        ));
      }
    }

    // ── Tip: Productivity patterns ──
    int activeThisWeek = 0;
    for (final project in projects) {
      final cached = scores[project.path];
      if (cached?.details.lastCommitDate != null) {
        final days = DateTime.now()
            .difference(cached!.details.lastCommitDate!)
            .inDays;
        if (days <= 7) activeThisWeek++;
      }
    }
    if (activeThisWeek > 0 && projects.length > 5) {
      insights.add(Insight(
        title: '$activeThisWeek project${activeThisWeek > 1 ? 's' : ''} active this week',
        description: activeThisWeek > 3
            ? 'You\'re context-switching across many projects. Consider focusing on fewer to increase depth.'
            : 'Good focus! Working on a manageable number of projects.',
        priority: InsightPriority.tip,
        category: InsightCategory.activity,
      ));
    }

    // ── Tip: Tech stack diversity ──
    final stackCounts = <String, int>{};
    for (final project in projects) {
      final stack = ProjectStack.detect(project.path);
      final label = stack.primary.label;
      if (label != 'Unknown') {
        stackCounts[label] = (stackCounts[label] ?? 0) + 1;
      }
    }
    if (stackCounts.length >= 3) {
      final sorted = stackCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      insights.add(Insight(
        title: '${stackCounts.length} tech stacks across your projects',
        description:
            'Top: ${sorted.take(3).map((e) => "${e.key} (${e.value})").join(", ")}. '
            'Diverse skills are valuable!',
        priority: InsightPriority.tip,
        category: InsightCategory.growth,
      ));
    }

    // Sort: critical first, then warning, info, tip
    insights.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return insights;
  }

  /// Generate summary stats
  static Future<InsightsSummary> generateSummary() async {
    final projects = await ProjectStorage.loadProjects();
    final scores = await HealthService.loadCache();

    int healthy = 0, attention = 0, critical = 0, stale = 0;
    int unpushed = 0, uncommitted = 0, noTests = 0, noGit = 0;
    int totalScore = 0, scoredCount = 0;
    String? mostNeglected;
    int mostNeglectedDays = 0;

    for (final project in projects) {
      final isGit = await GitService.isGitRepository(project.path);
      if (!isGit) {
        noGit++;
        continue;
      }

      final cached = scores[project.path];
      if (cached != null) {
        final score = cached.details.totalScore;
        totalScore += score;
        scoredCount++;

        if (score >= 80) {
          healthy++;
        } else if (score >= 50) {
          attention++;
        } else {
          critical++;
        }

        if (cached.staleness == StalenessLevel.stale ||
            cached.staleness == StalenessLevel.abandoned) {
          stale++;
        }

        if (!cached.details.hasTestFolder && !cached.details.hasTestFiles) {
          noTests++;
        }

        if (cached.details.lastCommitDate != null) {
          final days = DateTime.now()
              .difference(cached.details.lastCommitDate!)
              .inDays;
          if (days > mostNeglectedDays) {
            mostNeglectedDays = days;
            mostNeglected = project.name;
          }
        }
      }

      final unpushedCount = await GitService.getUnpushedCommitCount(project.path);
      if (unpushedCount > 0) unpushed++;

      final hasChanges = await GitService.hasUncommittedChanges(project.path);
      if (hasChanges) uncommitted++;
    }

    return InsightsSummary(
      totalProjects: projects.length,
      healthyCount: healthy,
      attentionCount: attention,
      criticalCount: critical,
      staleCount: stale,
      unpushedCount: unpushed,
      uncommittedCount: uncommitted,
      noTestsCount: noTests,
      noGitCount: noGit,
      avgHealthScore: scoredCount > 0 ? totalScore / scoredCount : 0,
      mostNeglectedProject: mostNeglected,
      mostNeglectedDays: mostNeglectedDays,
    );
  }
}
