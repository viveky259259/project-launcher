import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../services/platform_helper.dart';
import '../services/stats_service.dart';
import 'package:launcher_theme/launcher_theme.dart';
import '../widgets/sidebar.dart';
import 'health_screen.dart';
import 'insights_screen.dart';
import 'referral_screen.dart';
import 'subscription_screen.dart';
import 'team_screen.dart';

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

  // Date range — defaults to Jan 1 of current year → today
  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(DateTime.now().year, 1, 1);
    _toDate = DateTime.now();
    _loadStats();
  }

  Future<void> _loadStats({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _isGenerating = forceRefresh;
    });

    // Check if using default range (Jan 1 current year)
    final defaultFrom = DateTime(DateTime.now().year, 1, 1);
    final isDefault = _fromDate.year == defaultFrom.year &&
        _fromDate.month == defaultFrom.month &&
        _fromDate.day == defaultFrom.day &&
        _toDate.difference(DateTime.now()).inDays.abs() < 1;

    final stats = await StatsService.generateStats(
      forceRefresh: forceRefresh,
      from: isDefault ? null : _fromDate,
      to: isDefault ? null : _toDate,
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

      final bytes = byteData.buffer.asUint8List();

      // Save to Desktop
      final desktopPath = '${PlatformHelper.desktopDir}${Platform.pathSeparator}code_wrapped_${_fromDate.year}.png';
      final file = File(desktopPath);
      await file.writeAsBytes(bytes);

      // Also copy image to clipboard
      await Clipboard.setData(ClipboardData(text: StatsService.getShareableText(_stats!)));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Desktop & stats copied to clipboard'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => PlatformHelper.openFile(desktopPath),
            ),
          ),
        );
      }
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
            isPro: true,
            onNavigate: (route) {
              if (route == 'year_review') return;
              Navigator.of(context).pop();
              if (route == 'home' || route == 'projects') {
                // Already going back to home
              } else if (route == 'health') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HealthScreen()),
                );
              } else if (route == 'insights') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
                );
              } else if (route == 'team') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TeamScreen()),
                );
              } else if (route == 'referrals') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReferralScreen()),
                );
              } else if (route == 'subscription') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
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

  String _formatDateShort(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _reviewTitle() {
    // If range is within same year and starts from Jan 1, show "2026 Year in Review"
    if (_fromDate.month == 1 && _fromDate.day == 1 && _fromDate.year == _toDate.year) {
      return '${_fromDate.year} Year in Review';
    }
    // If same year but custom range
    if (_fromDate.year == _toDate.year) {
      return '${_fromDate.year} Review';
    }
    return 'Code Review';
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2015),
      lastDate: _toDate,
    );
    if (picked != null && picked != _fromDate) {
      setState(() => _fromDate = picked);
      _loadStats(forceRefresh: true);
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _toDate) {
      setState(() => _toDate = picked);
      _loadStats(forceRefresh: true);
    }
  }

  void _applyPreset(DateTime from, DateTime to) {
    setState(() {
      _fromDate = from;
      _toDate = to;
    });
    _loadStats(forceRefresh: true);
  }

  Widget _buildStatsView(ColorScheme cs) {
    final stats = _stats!;
    final year = _fromDate.year;

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
                          _reviewTitle(),
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
                    const SizedBox(height: 8),
                    // Date range picker row
                    Row(
                      children: [
                        _DateRangeChip(
                          label: _formatDateShort(_fromDate),
                          icon: Icons.calendar_today_rounded,
                          onTap: _pickFromDate,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward_rounded, size: 14, color: cs.onSurfaceVariant),
                        ),
                        _DateRangeChip(
                          label: _formatDateShort(_toDate),
                          icon: Icons.calendar_today_rounded,
                          onTap: _pickToDate,
                        ),
                        const SizedBox(width: 12),
                        // Quick presets
                        _PresetChip(
                          label: '${DateTime.now().year}',
                          isActive: _fromDate.month == 1 && _fromDate.day == 1 && _fromDate.year == DateTime.now().year,
                          onTap: () => _applyPreset(
                            DateTime(DateTime.now().year, 1, 1),
                            DateTime.now(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _PresetChip(
                          label: '${DateTime.now().year - 1}',
                          isActive: _fromDate.year == DateTime.now().year - 1 && _fromDate.month == 1 && _fromDate.day == 1 && _toDate.year == DateTime.now().year - 1,
                          onTap: () => _applyPreset(
                            DateTime(DateTime.now().year - 1, 1, 1),
                            DateTime(DateTime.now().year - 1, 12, 31),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _PresetChip(
                          label: 'Last 6mo',
                          isActive: false,
                          onTap: () => _applyPreset(
                            DateTime.now().subtract(const Duration(days: 183)),
                            DateTime.now(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _PresetChip(
                          label: 'Last 12mo',
                          isActive: false,
                          onTap: () => _applyPreset(
                            DateTime.now().subtract(const Duration(days: 365)),
                            DateTime.now(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _PresetChip(
                          label: 'All Time',
                          isActive: _fromDate.year <= 2015,
                          onTap: () => _applyPreset(
                            DateTime(2015, 1, 1),
                            DateTime.now(),
                          ),
                        ),
                      ],
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

  String _topLanguage() {
    if (stats.languageDistribution.isEmpty) return '';
    final sorted = stats.languageDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  @override
  Widget build(BuildContext context) {
    final topLang = _topLanguage();

    // Sort monthly data for chart
    final months = stats.monthlyActivity.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxCommits = months.isEmpty ? 1 : months.map((e) => e.value).reduce(math.max).clamp(1, double.infinity);

    return Container(
      width: 480,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.rocket_launch, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROJECT LAUNCHER',
                    style: AppTypography.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 2.5,
                    ),
                  ),
                  Text(
                    '$year CODE WRAPPED',
                    style: AppTypography.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Main stat — total commits
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatBigNumber(stats.totalCommits),
                style: AppTypography.mono(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'commits',
                  style: AppTypography.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Mini monthly activity chart
          if (months.isNotEmpty) ...[
            SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: months.map((entry) {
                  final fraction = entry.value / maxCommits;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: (fraction * 36).clamp(2, 36),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.accent.withValues(alpha: 0.4),
                                  AppColors.accent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _monthLabel(entry.key),
                            style: AppTypography.inter(fontSize: 8, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Divider
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 20),

          // Stats grid
          Row(
            children: [
              _WrappedStat(value: stats.totalProjects.toString(), label: 'projects'),
              _WrappedStat(value: stats.activeProjectsCount.toString(), label: 'active'),
              _WrappedStat(value: '${stats.estimatedCodingHours}h', label: 'coding hours'),
              _WrappedStat(value: '${stats.longestStreak}d', label: 'streak'),
            ],
          ),

          // Most active project
          if (stats.mostActiveProject != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                          style: AppTypography.inter(fontSize: 10, color: Colors.white38),
                        ),
                        Text(
                          stats.mostActiveProject!,
                          style: AppTypography.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
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

          // Top language badge
          if (topLang.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE879F9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE879F9).withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.code_rounded, size: 14, color: Color(0xFFE879F9)),
                  const SizedBox(width: 8),
                  Text(
                    'Top language: ',
                    style: AppTypography.inter(fontSize: 12, color: Colors.white38),
                  ),
                  Text(
                    topLang,
                    style: AppTypography.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE879F9),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Branding footer
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.rocket_launch, size: 12, color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(width: 6),
              Text(
                'Made with Project Launcher',
                style: AppTypography.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              const Spacer(),
              Text(
                'projectlauncher.dev',
                style: AppTypography.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBigNumber(int n) {
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}k';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  String _monthLabel(String key) {
    // key is "YYYY-MM"
    const labels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    final month = int.tryParse(key.split('-').last) ?? 1;
    return labels[month - 1];
  }
}

class _WrappedStat extends StatelessWidget {
  final String value;
  final String label;

  const _WrappedStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTypography.mono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.inter(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

// -- Date Range Chip --

class _DateRangeChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DateRangeChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_DateRangeChip> createState() => _DateRangeChipState();
}

class _DateRangeChipState extends State<_DateRangeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? cs.surfaceContainerHighest
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _hovered
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : cs.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTypography.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Preset Chip --

class _PresetChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_PresetChip> createState() => _PresetChipState();
}

class _PresetChipState extends State<_PresetChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accent.withValues(alpha: 0.15)
                : _hovered
                    ? cs.surfaceContainerHighest
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : _hovered
                      ? cs.outline.withValues(alpha: 0.3)
                      : cs.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            widget.label,
            style: AppTypography.inter(
              fontSize: 11,
              fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
              color: widget.isActive ? AppColors.accent : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
