import 'package:flutter/material.dart';
import 'package:launcher_kit/launcher_kit.dart';
import '../services/super_admin_api.dart';
import '../widgets/admin_navbar.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  PlatformMetrics? _metrics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final metrics = await SuperAdminApi.getMetrics();
      setState(() {
        _metrics = metrics;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AdminNavbar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Failed to load metrics: $_error'),
          const SizedBox(height: 16),
          UkButton(label: 'Retry', onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final m = _metrics!;

    // Find max plan count for bar scaling
    final maxPlanCount = m.orgsByPlan.values.fold<int>(
        0, (max, v) => v > max ? v : max);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Platform Metrics',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),

          // Metric cards row
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Active Orgs',
                  value: _formatNumber(m.activeOrgs),
                  subtitle: '${m.totalOrgs} total',
                  icon: Icons.business_rounded,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: 'Total Members',
                  value: _formatNumber(m.totalMembers),
                  icon: Icons.group_rounded,
                  color: cs.secondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: 'Total Repos',
                  value: _formatNumber(m.totalRepos),
                  icon: Icons.source_rounded,
                  color: cs.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Organizations by Plan
          UkCard(
            header: const Text('Organizations by Plan'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (m.orgsByPlan.isEmpty)
                  Text(
                    'No data available.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                else
                  ...m.orgsByPlan.entries.map((entry) {
                    final fraction = maxPlanCount > 0
                        ? entry.value / maxPlanCount
                        : 0.0;
                    final planColor = switch (entry.key) {
                      'enterprise' => cs.primary,
                      'pro' => cs.secondary,
                      'starter' => cs.tertiary,
                      _ => cs.onSurfaceVariant,
                    };

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              _capitalizePlan(entry.key),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${entry.value}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: planColor,
                                  ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _PlanBar(
                              fraction: fraction,
                              color: planColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalizePlan(String plan) {
    if (plan.isEmpty) return plan;
    return '${plan[0].toUpperCase()}${plan.substring(1)}';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return UkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanBar extends StatelessWidget {
  const _PlanBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth * fraction;
        return Container(
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            width: barWidth.clamp(4.0, constraints.maxWidth),
            height: 20,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}
