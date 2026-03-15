import 'package:flutter/material.dart';
import '../services/insights_service.dart';
import '../services/launcher_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import 'health_screen.dart';
import 'year_review_screen.dart';
import 'referral_screen.dart';
import 'subscription_screen.dart';
import 'team_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLoading = true;
  bool _isPro = false;
  int _progress = 0;
  int _total = 0;
  List<Insight> _insights = [];
  InsightsSummary? _summary;
  InsightCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);

    final isPro = await PremiumService.isPro();
    final summary = await InsightsService.generateSummary();
    final insights = await InsightsService.generateInsights(
      onProgress: (current, total) {
        if (mounted) setState(() { _progress = current; _total = total; });
      },
    );

    if (mounted) {
      setState(() {
        _isPro = isPro;
        _summary = summary;
        _insights = insights;
        _isLoading = false;
      });
    }
  }

  List<Insight> get _filteredInsights {
    if (_filterCategory == null) return _insights;
    return _insights.where((i) => i.category == _filterCategory).toList();
  }

  int _countByPriority(InsightPriority priority) =>
      _insights.where((i) => i.priority == priority).length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          AppSidebar(
            activeRoute: 'insights',
            isPro: _isPro,
            onNavigate: (route) {
              if (route == 'insights') return;
              Navigator.of(context).pop();
              switch (route) {
                case 'health':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthScreen()));
                case 'year_review':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YearReviewScreen()));
                case 'referrals':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReferralScreen()));
                case 'team':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeamScreen()));
                case 'subscription':
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              }
            },
          ),
          Expanded(
            child: _isLoading ? _buildLoading(cs) : _buildContent(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 24),
          Text('Analyzing your projects...', style: Theme.of(context).textTheme.titleMedium),
          if (_total > 0) ...[
            const SizedBox(height: 12),
            Text('$_progress / $_total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    final criticalCount = _countByPriority(InsightPriority.critical);
    final warningCount = _countByPriority(InsightPriority.warning);
    final tipCount = _countByPriority(InsightPriority.info) + _countByPriority(InsightPriority.tip);

    return Column(
      children: [
        // Top bar
        Container(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('AI Insights',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text('BETA',
                            style: AppTypography.inter(
                              fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Actionable recommendations based on your project data.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _loadInsights,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              // Summary cards
              if (_summary != null) _buildSummaryRow(cs),
              const SizedBox(height: 24),

              // Filter chips
              _buildFilterChips(cs, criticalCount, warningCount, tipCount),
              const SizedBox(height: 20),

              // Insights list
              if (_filteredInsights.isEmpty)
                _buildEmptyState(cs)
              else
                ..._filteredInsights.map((insight) => _InsightCard(
                  insight: insight,
                  onAction: insight.projectPath != null
                      ? () => LauncherService.openInTerminal(insight.projectPath!)
                      : null,
                )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(ColorScheme cs) {
    final s = _summary!;
    return Row(
      children: [
        _SummaryTile(
          icon: Icons.favorite_rounded,
          label: 'Avg Health',
          value: '${s.avgHealthScore.round()}',
          color: s.avgHealthScore >= 80
              ? AppColors.success
              : s.avgHealthScore >= 50
                  ? AppColors.warning
                  : AppColors.error,
        ),
        const SizedBox(width: 12),
        _SummaryTile(
          icon: Icons.cloud_upload_outlined,
          label: 'Unpushed',
          value: '${s.unpushedCount}',
          color: s.unpushedCount > 0 ? AppColors.warning : AppColors.success,
        ),
        const SizedBox(width: 12),
        _SummaryTile(
          icon: Icons.edit_note_rounded,
          label: 'Uncommitted',
          value: '${s.uncommittedCount}',
          color: s.uncommittedCount > 0 ? AppColors.warning : AppColors.success,
        ),
        const SizedBox(width: 12),
        _SummaryTile(
          icon: Icons.hourglass_empty_rounded,
          label: 'Stale',
          value: '${s.staleCount}',
          color: s.staleCount > 0 ? AppColors.error : AppColors.success,
        ),
      ],
    );
  }

  Widget _buildFilterChips(ColorScheme cs, int critical, int warning, int tips) {
    return Wrap(
      spacing: 8,
      children: [
        _FilterChip(
          label: 'All (${_insights.length})',
          isSelected: _filterCategory == null,
          onTap: () => setState(() => _filterCategory = null),
        ),
        _FilterChip(
          label: 'Git (${ _insights.where((i) => i.category == InsightCategory.git).length})',
          isSelected: _filterCategory == InsightCategory.git,
          color: AppColors.accent,
          onTap: () => setState(() =>
              _filterCategory = _filterCategory == InsightCategory.git ? null : InsightCategory.git),
        ),
        _FilterChip(
          label: 'Tech Debt (${_insights.where((i) => i.category == InsightCategory.techDebt).length})',
          isSelected: _filterCategory == InsightCategory.techDebt,
          color: AppColors.warning,
          onTap: () => setState(() =>
              _filterCategory = _filterCategory == InsightCategory.techDebt ? null : InsightCategory.techDebt),
        ),
        _FilterChip(
          label: 'Activity (${_insights.where((i) => i.category == InsightCategory.activity).length})',
          isSelected: _filterCategory == InsightCategory.activity,
          color: AppColors.error,
          onTap: () => setState(() =>
              _filterCategory = _filterCategory == InsightCategory.activity ? null : InsightCategory.activity),
        ),
        _FilterChip(
          label: 'Health (${_insights.where((i) => i.category == InsightCategory.health).length})',
          isSelected: _filterCategory == InsightCategory.health,
          color: AppColors.success,
          onTap: () => setState(() =>
              _filterCategory = _filterCategory == InsightCategory.health ? null : InsightCategory.health),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 48,
              color: AppColors.success.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No insights in this category',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Summary Tile ──

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                  style: AppTypography.mono(
                    fontSize: 22, fontWeight: FontWeight.w700, color: color)),
                Text(label,
                  style: AppTypography.inter(
                    fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter Chip ──

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? c.withValues(alpha: 0.4) : cs.outline.withValues(alpha: 0.2)),
        ),
        child: Text(label,
          style: AppTypography.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? c : cs.onSurfaceVariant,
          )),
      ),
    );
  }
}

// ── Insight Card ──

class _InsightCard extends StatelessWidget {
  final Insight insight;
  final VoidCallback? onAction;

  const _InsightCard({required this.insight, this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _priorityColor(insight.priority);
    final icon = _priorityIcon(insight.priority);
    final categoryIcon = _categoryIcon(insight.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: insight.priority == InsightPriority.critical
              ? color.withValues(alpha: 0.4)
              : cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(insight.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600, color: cs.onSurface)),
                    ),
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(categoryIcon, size: 11, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(_categoryLabel(insight.category),
                            style: AppTypography.inter(
                              fontSize: 10, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(insight.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant, height: 1.4)),
                if (insight.projectName != null || onAction != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (insight.projectName != null)
                        Text(insight.projectName!,
                          style: AppTypography.mono(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.accent)),
                      const Spacer(),
                      if (onAction != null)
                        TextButton.icon(
                          onPressed: onAction,
                          icon: Icon(Icons.terminal_rounded, size: 14, color: color),
                          label: Text(insight.actionLabel ?? 'Open',
                            style: AppTypography.inter(
                              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(InsightPriority p) {
    switch (p) {
      case InsightPriority.critical: return AppColors.error;
      case InsightPriority.warning: return AppColors.warning;
      case InsightPriority.info: return AppColors.accent;
      case InsightPriority.tip: return AppColors.success;
    }
  }

  IconData _priorityIcon(InsightPriority p) {
    switch (p) {
      case InsightPriority.critical: return Icons.error_rounded;
      case InsightPriority.warning: return Icons.warning_rounded;
      case InsightPriority.info: return Icons.info_rounded;
      case InsightPriority.tip: return Icons.lightbulb_rounded;
    }
  }

  IconData _categoryIcon(InsightCategory c) {
    switch (c) {
      case InsightCategory.git: return Icons.fork_right_rounded;
      case InsightCategory.health: return Icons.favorite_rounded;
      case InsightCategory.activity: return Icons.timeline_rounded;
      case InsightCategory.techDebt: return Icons.build_rounded;
      case InsightCategory.growth: return Icons.trending_up_rounded;
    }
  }

  String _categoryLabel(InsightCategory c) {
    switch (c) {
      case InsightCategory.git: return 'Git';
      case InsightCategory.health: return 'Health';
      case InsightCategory.activity: return 'Activity';
      case InsightCategory.techDebt: return 'Tech Debt';
      case InsightCategory.growth: return 'Growth';
    }
  }
}
