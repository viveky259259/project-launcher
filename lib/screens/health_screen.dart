import 'package:flutter/material.dart';
import '../models/health_score.dart';
import '../models/project.dart';
import '../services/health_service.dart';
import '../services/project_storage.dart';
import '../services/premium_service.dart';
import '../screens/pro_screen.dart';
import '../main.dart';
import '../theme/app_theme.dart';

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
  int _filterIndex = 0; // 0=All, 1=Healthy, 2=Needs Attention, 3=Critical

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

  HealthCategory? get _filterCategory {
    switch (_filterIndex) {
      case 1: return HealthCategory.healthy;
      case 2: return HealthCategory.needsAttention;
      case 3: return HealthCategory.critical;
      default: return null;
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
    final healthyCount = _countByCategory(HealthCategory.healthy);
    final attentionCount = _countByCategory(HealthCategory.needsAttention);
    final criticalCount = _countByCategory(HealthCategory.critical);

    return Scaffold(
      body: Column(
        children: [
          // Top bar
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  color: cs.onSurface,
                ),
                const SizedBox(width: 8),
                Text('Project Health', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (!_isLoading)
                  TextButton.icon(
                    onPressed: _isRefreshing ? null : () => _loadHealthData(forceRefresh: true),
                    icon: _isRefreshing
                        ? SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh Analytics'),
                    style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          if (_isLoading)
            Expanded(child: _buildLoadingView(cs))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Summary cards with circular progress rings
                  Row(
                    children: [
                      _SummaryRingCard(
                        label: 'Healthy',
                        count: healthyCount,
                        total: _projectsHealth.length,
                        color: AppColors.success,
                        isSelected: _filterIndex == 1,
                        onTap: () => setState(() => _filterIndex = _filterIndex == 1 ? 0 : 1),
                      ),
                      const SizedBox(width: 12),
                      _SummaryRingCard(
                        label: 'Needs Attention',
                        count: attentionCount,
                        total: _projectsHealth.length,
                        color: AppColors.warning,
                        isSelected: _filterIndex == 2,
                        onTap: () => setState(() => _filterIndex = _filterIndex == 2 ? 0 : 2),
                      ),
                      const SizedBox(width: 12),
                      _SummaryRingCard(
                        label: 'Critical',
                        count: criticalCount,
                        total: _projectsHealth.length,
                        color: AppColors.error,
                        isSelected: _filterIndex == 3,
                        onTap: () => setState(() => _filterIndex = _filterIndex == 3 ? 0 : 3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tab bar
                  _CategoryTabs(
                    selectedIndex: _filterIndex,
                    totalCount: _projectsHealth.length,
                    onChanged: (i) => setState(() => _filterIndex = i),
                  ),
                  const SizedBox(height: 16),

                  // Project health cards
                  if (_filteredProjects.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Text(
                          'No projects in this category',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ..._filteredProjects.map((data) => _HealthCard(data: data)),

                  // Health History teaser
                  _HealthHistoryTeaser(
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
                  ),
                ],
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
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 24),
          Text('Analyzing project health...', style: Theme.of(context).textTheme.titleMedium),
          if (_total > 0) ...[
            const SizedBox(height: 16),
            Text('$_progress / $_total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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

// --- Summary Ring Card ---

class _SummaryRingCard extends StatefulWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SummaryRingCard({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SummaryRingCard> createState() => _SummaryRingCardState();
}

class _SummaryRingCardState extends State<_SummaryRingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = widget.total > 0 ? widget.count / widget.total : 0.0;

    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.color.withValues(alpha: 0.1)
                  : cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: widget.isSelected
                    ? widget.color.withValues(alpha: 0.5)
                    : _isHovered
                        ? cs.outline.withValues(alpha: 0.3)
                        : cs.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                // Count and label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.count.toString(),
                        style: AppTypography.mono(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: widget.color,
                        ),
                      ),
                    ],
                  ),
                ),
                // Circular ring
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CustomPaint(
                    painter: _RingPainter(
                      fraction: fraction,
                      color: widget.color,
                      backgroundColor: widget.color.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color backgroundColor;

  _RingPainter({required this.fraction, required this.color, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    const strokeWidth = 5.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = backgroundColor,
    );

    // Progress arc
    if (fraction > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -1.5708, // Start from top (-90 degrees)
        fraction * 6.2832, // Full circle = 2*pi
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

// --- Category Tabs ---

class _CategoryTabs extends StatelessWidget {
  final int selectedIndex;
  final int totalCount;
  final ValueChanged<int> onChanged;

  const _CategoryTabs({
    required this.selectedIndex,
    required this.totalCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labels = ['All Projects ($totalCount)', 'Healthy', 'Needs Attention', 'Critical'];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: labels.asMap().entries.map((entry) {
          final isActive = entry.key == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? AppColors.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                entry.value,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isActive ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// --- Health Card (redesigned) ---

class _HealthCard extends StatelessWidget {
  final _ProjectHealthData data;

  const _HealthCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = data.health.details;
    final staleness = data.health.staleness;
    final score = details.totalScore;
    final category = details.category;

    final categoryColor = _categoryColor(category);
    final categoryLabel = _categoryLabel(category);
    final stalenessLabel = staleness.label;
    final stalenessColor = _stalenessColor(staleness);

    final lastCommitText = details.lastCommitDate != null
        ? 'Last commit: ${_formatTimeAgo(details.lastCommitDate!)}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name + badge + score
          Row(
            children: [
              Text(
                data.project.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              // Health badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  categoryLabel,
                  style: AppTypography.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
              ),
              const Spacer(),
              // Score
              Text(
                '$score/100',
                style: AppTypography.mono(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: categoryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _shortenPath(data.project.path),
            style: AppTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),

          // Score breakdown bars
          _ScoreBar(label: 'Git Activity', score: details.gitScore, maxScore: 40),
          const SizedBox(height: 8),
          _ScoreBar(label: 'Dependencies', score: details.depsScore, maxScore: 30),
          const SizedBox(height: 8),
          _ScoreBar(label: 'Tests', score: details.testsScore, maxScore: 30),

          const SizedBox(height: 14),

          // Footer: last commit + staleness badge
          Row(
            children: [
              if (lastCommitText.isNotEmpty)
                Text(
                  lastCommitText,
                  style: AppTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: stalenessColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  stalenessLabel,
                  style: AppTypography.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: stalenessColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortenPath(String path) {
    final parts = path.split('/');
    if (parts.length > 2) {
      return '~/${parts.sublist(3).join('/')}';
    }
    return path;
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  Color _categoryColor(HealthCategory cat) {
    switch (cat) {
      case HealthCategory.healthy: return AppColors.success;
      case HealthCategory.needsAttention: return AppColors.warning;
      case HealthCategory.critical: return AppColors.error;
    }
  }

  String _categoryLabel(HealthCategory cat) {
    switch (cat) {
      case HealthCategory.healthy: return 'Healthy';
      case HealthCategory.needsAttention: return 'Needs Attention';
      case HealthCategory.critical: return 'Critical';
    }
  }

  Color _stalenessColor(StalenessLevel s) {
    switch (s) {
      case StalenessLevel.fresh: return AppColors.success;
      case StalenessLevel.warning: return AppColors.warning;
      case StalenessLevel.stale: return AppColors.error;
      case StalenessLevel.abandoned: return const Color(0xFF6B7280);
    }
  }
}

// --- Score Bar ---

class _ScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final int maxScore;

  const _ScoreBar({required this.label, required this.score, required this.maxScore});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = score / maxScore;
    final color = fraction >= 0.7
        ? AppColors.success
        : fraction >= 0.4
            ? AppColors.warning
            : AppColors.error;

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            '$score/$maxScore',
            style: AppTypography.mono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// --- Health History Teaser ---

class _HealthHistoryTeaser extends StatelessWidget {
  final bool isPro;
  final VoidCallback onTap;

  const _HealthHistoryTeaser({required this.isPro, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isPro ? cs.outline.withValues(alpha: 0.15) : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: isPro ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.trending_up_rounded, color: AppColors.warning, size: 22),
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
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (!isPro) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text('PRO', style: AppTypography.inter(
                              fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accent,
                            )),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPro
                          ? 'Track how your project health changes over time'
                          : 'Upgrade to Pro to track health trends over time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
