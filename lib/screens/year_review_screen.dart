import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/stats_service.dart';
import '../kit/kit.dart';

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
      // Capture the widget as an image
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/project_launcher_year_review.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // Share
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
      appBar: AppBar(
        title: const Text('Year in Review'),
        actions: [
          if (!_isLoading && _stats != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Regenerate stats',
              onPressed: () => _loadStats(forceRefresh: true),
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView(cs)
          : _stats == null
              ? _buildEmptyView(cs)
              : _buildStatsView(cs),
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
            _isGenerating ? 'Analyzing your projects...' : 'Loading stats...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_isGenerating && _total > 0) ...[
            const SizedBox(height: 16),
            Text(
              '$_progress / $_total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentProject,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
          Icon(
            Icons.insights_rounded,
            size: 64,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No stats available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add some projects to see your year in review',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsView(ColorScheme cs) {
    final stats = _stats!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Shareable card
          RepaintBoundary(
            key: _cardKey,
            child: _YearReviewCard(stats: stats),
          ),
          const SizedBox(height: 24),

          // Share button
          UkButton(
            label: 'Share Card',
            icon: Icons.share,
            onPressed: _shareCard,
          ),
          const SizedBox(height: 32),

          // Monthly activity chart
          Text(
            'Monthly Activity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _MonthlyActivityChart(monthlyActivity: stats.monthlyActivity),
        ],
      ),
    );
  }
}

class _YearReviewCard extends StatelessWidget {
  final YearInReviewStats stats;

  const _YearReviewCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.3),
            blurRadius: 20,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.rocket_launch,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Project Launcher',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${DateTime.now().year} Year in Review',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // Main stat
          Text(
            '${stats.totalCommits}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const Text(
            'commits this year',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 32),

          // Secondary stats
          Row(
            children: [
              _StatItem(
                value: stats.totalProjects.toString(),
                label: 'projects',
                icon: Icons.folder_rounded,
              ),
              const SizedBox(width: 24),
              _StatItem(
                value: stats.activeProjectsCount.toString(),
                label: 'active',
                icon: Icons.local_fire_department_rounded,
              ),
            ],
          ),

          if (stats.mostActiveProject != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Most Active Project',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          stats.mostActiveProject!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${stats.mostActiveProjectCommits}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _MonthlyActivityChart extends StatelessWidget {
  final Map<String, int> monthlyActivity;

  const _MonthlyActivityChart({required this.monthlyActivity});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sortedKeys = monthlyActivity.keys.toList()..sort();
    final maxValue = monthlyActivity.values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: sortedKeys.map((key) {
          final value = monthlyActivity[key] ?? 0;
          final height = maxValue > 0 ? (value / maxValue) * 140 : 0.0;
          final month = key.split('-').last;
          final monthNames = ['', 'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
          final monthIndex = int.tryParse(month) ?? 0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (value > 0)
                    Text(
                      value.toString(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: height,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    monthNames[monthIndex],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
