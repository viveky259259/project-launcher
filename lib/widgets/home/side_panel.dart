import 'package:flutter/material.dart';
import 'package:launcher_theme/launcher_theme.dart';
import 'filter_bar.dart';

class HomeSidePanel extends StatelessWidget {
  final int totalProjects;
  final int healthyCount;
  final int needsAttentionCount;
  final bool isPro;
  final VoidCallback onYearReviewTap;
  final VoidCallback onHealthTap;
  final VoidCallback? onInsightsTap;
  final List<double> weeklyActivity;
  final Map<ActivityFilter, int> activityCounts;

  const HomeSidePanel({
    super.key,
    required this.totalProjects,
    required this.healthyCount,
    required this.needsAttentionCount,
    required this.isPro,
    required this.onYearReviewTap,
    required this.onHealthTap,
    this.onInsightsTap,
    this.weeklyActivity = const [0, 0, 0, 0, 0, 0, 0],
    this.activityCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skin = AppSkin.maybeOf(context);
    final panelWidth = skin?.spacing.sidePanelWidth ?? 240.0;
    final panelPadding = skin?.spacing.md ?? 16.0;

    return Container(
      width: panelWidth,
      padding: EdgeInsets.fromLTRB(panelPadding, panelPadding, panelPadding, 32),
      child: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Health summary
          GestureDetector(
            onTap: onHealthTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Health',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HealthRow(
                    label: 'Total Projects',
                    value: totalProjects.toString(),
                    color: cs.onSurface,
                  ),
                  const SizedBox(height: 8),
                  _HealthRow(
                    label: 'Healthy',
                    value: healthyCount.toString(),
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 8),
                  _HealthRow(
                    label: 'Needs Attention',
                    value: needsAttentionCount.toString(),
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Activity (7d) mini chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity (7d)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: _MiniBarChart(data: weeklyActivity),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                      .map((d) => Text(
                            d,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 9,
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Activity breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                _ActivityRow(
                  label: 'This Week',
                  value: activityCounts[ActivityFilter.thisWeek] ?? 0,
                  total: totalProjects,
                  color: AppColors.success,
                ),
                const SizedBox(height: 8),
                _ActivityRow(
                  label: 'Last Week',
                  value: activityCounts[ActivityFilter.lastWeek] ?? 0,
                  total: totalProjects,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 8),
                _ActivityRow(
                  label: 'This Month',
                  value: activityCounts[ActivityFilter.thisMonth] ?? 0,
                  total: totalProjects,
                  color: AppColors.warning,
                ),
                const SizedBox(height: 8),
                _ActivityRow(
                  label: 'Older',
                  value: (activityCounts[ActivityFilter.lastMonth] ?? 0) + (activityCounts[ActivityFilter.older] ?? 0),
                  total: totalProjects,
                  color: const Color(0xFF6B7280),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // AI Insights card
          if (onInsightsTap != null)
            GestureDetector(
              onTap: onInsightsTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Insights',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Smart recommendations',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),

          if (onInsightsTap != null)
            const SizedBox(height: 12),

          // Year in Review promo card
          GestureDetector(
            onTap: onYearReviewTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0E3A5C),
                    Color(0xFF1A1040),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Year in Review',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visualize your ${DateTime.now().year} coding journey with Pro.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      isPro ? 'View Now' : 'Upgrade Now',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HealthRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
          ),
        ),
        Text(
          value,
          style: AppTypography.mono(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<double> data;

  const _MiniBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<double>(0, (a, b) => a > b ? a : b);
    final normalized = maxVal > 0
        ? data.map((v) => v / maxVal).toList()
        : data;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: normalized.map((value) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              height: value > 0 ? 60 * value.clamp(0.05, 1.0) : 2,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.6 + (value * 0.4)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ActivityRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '$value',
              style: AppTypography.mono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: value > 0 ? color : cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 3,
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: cs.outline.withValues(alpha: 0.1),
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
