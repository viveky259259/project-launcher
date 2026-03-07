import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';

class YearReviewScreen extends StatefulWidget {
  const YearReviewScreen({super.key});

  @override
  State<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends State<YearReviewScreen> {
  bool _isLoading = true;
  bool _isGenerating = false;
  String _currentProject = '';
  int _progress = 0;
  int _total = 0;
  YearInReviewStats? _stats;
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _isGenerating = forceRefresh;
    });

    final stats = await StatsService.generateStats(
      forceRefresh: forceRefresh,
      onProgress: (project, current, total) {
        if (mounted) {
          setState(() {
            _currentProject = project;
            _progress = current;
            _total = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
        _isGenerating = false;
      });
    }
  }

  Future<void> _shareCard() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/project_launcher_year_review.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: StatsService.getShareableText(_stats!),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          // Sidebar
          AppSidebar(
            activeRoute: 'year_review',
            onNavigate: (route) {
              if (route != 'year_review') {
                Navigator.of(context).pop();
              }
            },
          ),
          // Main content
          Expanded(
            child: _isLoading
                ? _buildLoadingView(cs)
                : _stats == null
                    ? _buildEmptyView(cs)
                    : _buildStatsView(cs),
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
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isGenerating ? 'Analyzing your projects...' : 'Loading stats...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_isGenerating && _total > 0) ...[
            const SizedBox(height: 16),
            Text(
              '$_progress / $_total',
              style: AppTypography.mono(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentProject,
              style: AppTypography.mono(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyView(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_rounded, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No stats available', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Add some projects to see your year in review',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsView(ColorScheme cs) {
    final stats = _stats!;
    final year = DateTime.now().year;

    return Column(
      children: [
        // Top bar
        Container(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$year Year in Review',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            'PRO',
                            style: AppTypography.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A deep dive into your coding journey over the last 12 months.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _ActionButton(
                icon: Icons.refresh_rounded,
                label: 'Refresh',
                onPressed: () => _loadStats(forceRefresh: true),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.share_rounded,
                label: 'Share Stats',
                onPressed: _stats != null ? _shareCard : null,
                isPrimary: true,
              ),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4 stat cards
                _StatCardsRow(stats: stats),
                const SizedBox(height: 32),

                // Commit Activity chart
                _SectionTitle(title: 'Commit Activity'),
                const SizedBox(height: 16),
                _CommitActivityChart(monthlyActivity: stats.monthlyActivity),
                const SizedBox(height: 32),

                // Two columns: Languages + Most Active Projects
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Languages
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(title: 'Top Languages'),
                          const SizedBox(height: 16),
                          _LanguageChart(languages: stats.languageDistribution),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Most Active Projects
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(title: 'Most Active Projects'),
                          const SizedBox(height: 16),
                          _ProjectRankingList(
                            projectCommits: stats.projectCommits,
                            totalCommits: stats.totalCommits,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Shareable wrapped card
                _SectionTitle(title: '$year Wrapped'),
                const SizedBox(height: 16),
                Center(
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _WrappedCard(stats: stats, year: year),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -- Action button in top bar --

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: isPrimary ? AppColors.accent : cs.onSurfaceVariant,
        backgroundColor: isPrimary ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: isPrimary
              ? BorderSide(color: AppColors.accent.withValues(alpha: 0.3))
              : BorderSide.none,
        ),
        textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// -- Section title --

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

// -- 4 Stat Cards Row --

class _StatCardsRow extends StatelessWidget {
  final YearInReviewStats stats;
  const _StatCardsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.commit_rounded,
            iconColor: AppColors.accent,
            label: 'Total Commits',
            value: _formatNumber(stats.totalCommits),
            delta: '+${stats.activeProjectsCount} active',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.rocket_launch_rounded,
            iconColor: const Color(0xFFE879F9),
            label: 'Projects Managed',
            value: stats.totalProjects.toString(),
            delta: '+${stats.activeProjectsCount} active',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.schedule_rounded,
            iconColor: const Color(0xFFA78BFA),
            label: 'Coding Hours',
            value: _formatNumber(stats.estimatedCodingHours),
            delta: 'estimated',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFBBF24),
            label: 'Longest Streak',
            value: '${stats.longestStreak}',
            delta: 'days',
          ),
        ),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return n.toString();
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String delta;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  delta,
                  style: AppTypography.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AppTypography.mono(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// -- Commit Activity Bar Chart --

class _CommitActivityChart extends StatelessWidget {
  final Map<String, int> monthlyActivity;
  const _CommitActivityChart({required this.monthlyActivity});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sortedKeys = monthlyActivity.keys.toList()..sort();
    final maxValue = monthlyActivity.values.fold(0, (a, b) => a > b ? a : b);
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(sortedKeys.length, (i) {
          final key = sortedKeys[i];
          final value = monthlyActivity[key] ?? 0;
          final barHeight = maxValue > 0 ? (value / maxValue) * 150 : 0.0;
          final month = key.split('-').last;
          final monthIndex = (int.tryParse(month) ?? 1) - 1;
          final monthLabel = monthIndex < monthNames.length ? monthNames[monthIndex] : '';

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (value > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        value.toString(),
                        style: AppTypography.mono(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: barHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.accent.withValues(alpha: 0.6),
                          AppColors.accent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    monthLabel,
                    style: AppTypography.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// -- Language Donut Chart --

class _LanguageChart extends StatelessWidget {
  final Map<String, int> languages;
  const _LanguageChart({required this.languages});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (languages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text(
            'No language data available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final total = languages.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Donut chart
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _DonutPainter(
                segments: languages.entries.map((e) {
                  return _DonutSegment(
                    value: e.value.toDouble(),
                    color: AppColors.getLanguageColor(e.key),
                  );
                }).toList(),
                total: total.toDouble(),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total.toString(),
                      style: AppTypography.mono(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'projects',
                      style: AppTypography.inter(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          ...languages.entries.take(6).map((e) {
            final pct = (e.value / total * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.getLanguageColor(e.key),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.key,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: AppTypography.mono(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DonutSegment {
  final double value;
  final Color color;
  const _DonutSegment({required this.value, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double total;

  _DonutPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 20.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    double startAngle = -math.pi / 2;
    for (final segment in segments) {
      final sweepAngle = (segment.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle - 0.02, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

// -- Most Active Projects List --

class _ProjectRankingList extends StatelessWidget {
  final Map<String, int> projectCommits;
  final int totalCommits;

  const _ProjectRankingList({required this.projectCommits, required this.totalCommits});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = projectCommits.entries.take(8).toList();

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text(
            'No active projects this year',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final maxCommits = entries.first.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          final barFraction = maxCommits > 0 ? entry.value / maxCommits : 0.0;

          return Padding(
            padding: EdgeInsets.only(bottom: i < entries.length - 1 ? 12 : 0),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '#${i + 1}',
                    style: AppTypography.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: i < 3 ? AppColors.accent : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      backgroundColor: cs.outline.withValues(alpha: 0.1),
                      color: AppColors.accent.withValues(alpha: 0.7),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 50,
                  child: Text(
                    entry.value.toString(),
                    textAlign: TextAlign.right,
                    style: AppTypography.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// -- Shareable Wrapped Card --

class _WrappedCard extends StatelessWidget {
  final YearInReviewStats stats;
  final int year;

  const _WrappedCard({required this.stats, required this.year});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.rocket_launch, color: AppColors.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                'PROJECT LAUNCHER',
                style: AppTypography.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$year WRAPPED',
            style: AppTypography.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          // Main stat
          Text(
            '${stats.totalCommits}',
            style: AppTypography.mono(
              fontSize: 64,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            'commits this year',
            style: AppTypography.inter(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 32),

          // Secondary stats
          Row(
            children: [
              _WrappedStat(value: stats.totalProjects.toString(), label: 'projects'),
              const SizedBox(width: 32),
              _WrappedStat(value: stats.activeProjectsCount.toString(), label: 'active'),
              const SizedBox(width: 32),
              _WrappedStat(value: '${stats.estimatedCodingHours}h', label: 'coding'),
            ],
          ),

          if (stats.mostActiveProject != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Most Active',
                          style: AppTypography.inter(fontSize: 11, color: Colors.white54),
                        ),
                        Text(
                          stats.mostActiveProject!,
                          style: AppTypography.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${stats.mostActiveProjectCommits}',
                    style: AppTypography.mono(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WrappedStat extends StatelessWidget {
  final String value;
  final String label;

  const _WrappedStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTypography.mono(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: AppTypography.inter(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}
