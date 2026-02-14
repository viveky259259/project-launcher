import 'package:flutter/material.dart';
import '../models/health_score.dart';
import '../models/project.dart';
import '../services/health_service.dart';
import '../services/project_storage.dart';
import '../services/premium_service.dart';
import '../screens/pro_screen.dart';
import '../main.dart';
import '../kit/kit.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isPro = false;
  int _progress = 0;
  int _total = 0;
  List<_ProjectHealthData> _projectsHealth = [];
  HealthCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
    _loadProStatus();
  }

  Future<void> _loadProStatus() async {
    final isPro = await PremiumService.isPro();
    if (mounted) setState(() => _isPro = isPro);
  }

  Future<void> _loadHealthData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = !forceRefresh;
      _isRefreshing = forceRefresh;
    });

    final projects = await ProjectStorage.loadProjects();
    final healthData = <_ProjectHealthData>[];

    for (var i = 0; i < projects.length; i++) {
      final project = projects[i];
      setState(() {
        _progress = i + 1;
        _total = projects.length;
      });

      final health = await HealthService.getHealthScore(
        project.path,
        forceRefresh: forceRefresh,
      );

      healthData.add(_ProjectHealthData(project: project, health: health));
    }

    // Sort by health score (lowest first for attention)
    healthData.sort((a, b) =>
        a.health.details.totalScore.compareTo(b.health.details.totalScore));

    if (mounted) {
      setState(() {
        _projectsHealth = healthData;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  List<_ProjectHealthData> get _filteredProjects {
    if (_filterCategory == null) return _projectsHealth;
    return _projectsHealth
        .where((p) => p.health.details.category == _filterCategory)
        .toList();
  }

  int _countByCategory(HealthCategory category) {
    return _projectsHealth.where((p) => p.health.details.category == category).length;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Health'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isRefreshing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : const Icon(Icons.refresh),
              tooltip: 'Refresh all',
              onPressed: _isRefreshing ? null : () => _loadHealthData(forceRefresh: true),
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView(cs)
          : Column(
              children: [
                // Summary cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _SummaryCard(
                        label: 'Healthy',
                        count: _countByCategory(HealthCategory.healthy),
                        color: Colors.green,
                        isSelected: _filterCategory == HealthCategory.healthy,
                        onTap: () => setState(() {
                          _filterCategory = _filterCategory == HealthCategory.healthy
                              ? null
                              : HealthCategory.healthy;
                        }),
                      ),
                      const SizedBox(width: 12),
                      _SummaryCard(
                        label: 'Needs Attention',
                        count: _countByCategory(HealthCategory.needsAttention),
                        color: Colors.orange,
                        isSelected: _filterCategory == HealthCategory.needsAttention,
                        onTap: () => setState(() {
                          _filterCategory = _filterCategory == HealthCategory.needsAttention
                              ? null
                              : HealthCategory.needsAttention;
                        }),
                      ),
                      const SizedBox(width: 12),
                      _SummaryCard(
                        label: 'Critical',
                        count: _countByCategory(HealthCategory.critical),
                        color: Colors.red,
                        isSelected: _filterCategory == HealthCategory.critical,
                        onTap: () => setState(() {
                          _filterCategory = _filterCategory == HealthCategory.critical
                              ? null
                              : HealthCategory.critical;
                        }),
                      ),
                    ],
                  ),
                ),

                // Project list
                Expanded(
                  child: _filteredProjects.isEmpty
                      ? Center(
                          child: Text(
                            'No projects in this category',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredProjects.length + 1,
                          itemBuilder: (context, index) {
                            if (index < _filteredProjects.length) {
                              final data = _filteredProjects[index];
                              return _ProjectHealthCard(
                                data: data,
                                onRefresh: () async {
                                  await HealthService.invalidateCache(data.project.path);
                                  _loadHealthData(forceRefresh: false);
                                },
                              );
                            }
                            // Health History teaser card at the bottom
                            return _HealthHistoryTeaser(
                              isPro: _isPro,
                              onTap: () {
                                if (!_isPro) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProScreen(
                                        onStatusChanged: () {
                                          ProjectLauncherApp.of(context)?.refreshPremiumStatus();
                                          _loadProStatus();
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingView(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Analyzing project health...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_total > 0) ...[
            const SizedBox(height: 16),
            Text(
              '$_progress / $_total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectHealthData {
  final Project project;
  final CachedHealthScore health;

  const _ProjectHealthData({required this.project, required this.health});
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : cs.outline.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectHealthCard extends StatelessWidget {
  final _ProjectHealthData data;
  final VoidCallback onRefresh;

  const _ProjectHealthCard({
    required this.data,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = data.health.details;
    final staleness = data.health.staleness;

    final stalenessColor = _getStalenessColor(staleness);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Health score circle
              _HealthScoreIndicator(
                score: details.totalScore,
                size: 48,
              ),
              const SizedBox(width: 16),
              // Project info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.project.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (staleness != StalenessLevel.fresh)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: stalenessColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              staleness.label,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: stalenessColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.project.path,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Score breakdown
          Row(
            children: [
              _ScoreCategory(
                label: 'Git',
                score: details.gitScore,
                maxScore: 40,
                icon: Icons.commit,
              ),
              const SizedBox(width: 16),
              _ScoreCategory(
                label: 'Dependencies',
                score: details.depsScore,
                maxScore: 30,
                icon: Icons.inventory_2_rounded,
              ),
              const SizedBox(width: 16),
              _ScoreCategory(
                label: 'Tests',
                score: details.testsScore,
                maxScore: 30,
                icon: Icons.science_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Details
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (details.hasRecentCommits)
                _DetailChip(label: 'Recent commits', positive: true),
              if (!details.hasRecentCommits)
                _DetailChip(label: 'No recent commits', positive: false),
              if (details.noUncommittedChanges)
                _DetailChip(label: 'Clean working tree', positive: true),
              if (!details.noUncommittedChanges)
                _DetailChip(label: 'Uncommitted changes', positive: false),
              if (details.hasDependencyFile && details.dependencyFileType != null)
                _DetailChip(label: details.dependencyFileType!, positive: true),
              if (details.hasTestFolder)
                _DetailChip(label: 'Has tests', positive: true),
              if (!details.hasTestFolder)
                _DetailChip(label: 'No tests', positive: false),
            ],
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Color _getStalenessColor(StalenessLevel staleness) {
    switch (staleness) {
      case StalenessLevel.fresh:
        return Colors.green;
      case StalenessLevel.warning:
        return Colors.orange;
      case StalenessLevel.stale:
        return Colors.red;
      case StalenessLevel.abandoned:
        return Colors.grey;
    }
  }
}

class _HealthScoreIndicator extends StatelessWidget {
  final int score;
  final double size;

  const _HealthScoreIndicator({
    required this.score,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
            strokeWidth: 4,
          ),
          Text(
            score.toString(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}

class _ScoreCategory extends StatelessWidget {
  final String label;
  final int score;
  final int maxScore;
  final IconData icon;

  const _ScoreCategory({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percentage = score / maxScore;
    final color = percentage >= 0.7
        ? Colors.green
        : percentage >= 0.4
            ? Colors.orange
            : Colors.red;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              Text(
                '$score/$maxScore',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final bool positive;

  const _DetailChip({
    required this.label,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final color = positive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.check_circle : Icons.warning,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _HealthHistoryTeaser extends StatelessWidget {
  final bool isPro;
  final VoidCallback onTap;

  const _HealthHistoryTeaser({
    required this.isPro,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPro
              ? cs.outline.withValues(alpha: 0.2)
              : const Color(0xFFFFD700).withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: isPro ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFFFFD700),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Health History & Trends',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (!isPro) ...[
                          const SizedBox(width: 8),
                          UkBadge('PRO', variant: UkBadgeVariant.neutral),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPro
                          ? 'Track how your project health changes over time'
                          : 'Upgrade to Pro to track health trends over time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (!isPro)
                Icon(Icons.lock, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
