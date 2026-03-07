import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HomeSidePanel extends StatelessWidget {
  final int totalProjects;
  final int healthyCount;
  final int needsAttentionCount;
  final bool isPro;
  final VoidCallback onYearReviewTap;
  final VoidCallback onHealthTap;

  const HomeSidePanel({
    super.key,
    required this.totalProjects,
    required this.healthyCount,
    required this.needsAttentionCount,
    required this.isPro,
    required this.onYearReviewTap,
    required this.onHealthTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
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
                  child: _MiniBarChart(),
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
                    'Visualize your 2024 coding journey with Pro.',
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
  // Placeholder data - will be replaced with real activity data
  final List<double> data = const [0.3, 0.7, 0.5, 0.9, 0.6, 0.2, 0.4];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((value) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              height: 60 * value,
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
