import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  Future<void> _init() async {
    await NotificationService.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Top bar
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: cs.outline.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  color: cs.onSurface,
                ),
                const SizedBox(width: 8),
                Text('Notifications',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 10),
                if (NotificationService.unreadCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text('${NotificationService.unreadCount} new',
                        style: AppTypography.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error)),
                  ),
                const Spacer(),
                // Monitoring toggle
                Row(
                  children: [
                    Text('Monitoring',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    Switch(
                      value: NotificationService.isRunning,
                      activeThumbColor: AppColors.accent,
                      onChanged: (enabled) {
                        if (enabled) {
                          NotificationService.start();
                        } else {
                          NotificationService.stop();
                        }
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: cs.outline.withValues(alpha: 0.1))),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.accent,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: AppColors.accent,
              tabs: const [
                Tab(text: 'Rules'),
                Tab(text: 'History'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRulesTab(cs),
                _buildHistoryTab(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesTab(ColorScheme cs) {
    final rules = NotificationService.rules;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded,
                  size: 20, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Configure when to receive desktop notifications about your projects. '
                  'Checks run every 30 minutes when monitoring is enabled.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ...rules.map((rule) => _NotificationRuleCard(
              rule: rule,
              onToggle: (enabled) async {
                await NotificationService.updateRule(
                    rule.copyWith(enabled: enabled));
                setState(() {});
              },
              onThresholdChanged: (threshold) async {
                await NotificationService.updateRule(
                    rule.copyWith(threshold: threshold));
                setState(() {});
              },
            )),
      ],
    );
  }

  Widget _buildHistoryTab(ColorScheme cs) {
    final history = NotificationService.history;

    return Column(
      children: [
        if (history.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text('${history.length} notifications',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await NotificationService.markAllRead();
                    setState(() {});
                  },
                  child: const Text('Mark all read'),
                ),
                TextButton(
                  onPressed: () async {
                    await NotificationService.clearHistory();
                    setState(() {});
                  },
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 40, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('No notifications yet',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('Enable monitoring to start receiving alerts',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final notif = history[index];
                    return _NotificationHistoryCard(notification: notif);
                  },
                ),
        ),
      ],
    );
  }
}

class _NotificationRuleCard extends StatelessWidget {
  final NotificationRule rule;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onThresholdChanged;

  const _NotificationRuleCard({
    required this.rule,
    required this.onToggle,
    required this.onThresholdChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _ruleColor(rule.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: rule.enabled
              ? color.withValues(alpha: 0.25)
              : cs.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child:
                    Icon(_ruleIcon(rule.type), size: 18, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.label,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(rule.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Switch(
                value: rule.enabled,
                activeThumbColor: color,
                onChanged: onToggle,
              ),
            ],
          ),
          if (rule.enabled) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Threshold: ',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: rule.threshold.toDouble(),
                    min: _minThreshold(rule.type),
                    max: _maxThreshold(rule.type),
                    divisions: _divisions(rule.type),
                    activeColor: color,
                    label: _thresholdLabel(rule),
                    onChanged: (val) => onThresholdChanged(val.round()),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    _thresholdLabel(rule),
                    style: AppTypography.mono(
                        fontSize: 12,
                        color: color),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _ruleIcon(NotificationType type) {
    switch (type) {
      case NotificationType.unpushedCommits:
        return Icons.cloud_upload_rounded;
      case NotificationType.staleChanges:
        return Icons.edit_note_rounded;
      case NotificationType.lowHealth:
        return Icons.health_and_safety_rounded;
      case NotificationType.projectStale:
        return Icons.schedule_rounded;
    }
  }

  Color _ruleColor(NotificationType type) {
    switch (type) {
      case NotificationType.unpushedCommits:
        return AppColors.accent;
      case NotificationType.staleChanges:
        return AppColors.warning;
      case NotificationType.lowHealth:
        return AppColors.error;
      case NotificationType.projectStale:
        return const Color(0xFF8B5CF6);
    }
  }

  double _minThreshold(NotificationType type) {
    switch (type) {
      case NotificationType.unpushedCommits:
        return 1;
      case NotificationType.staleChanges:
        return 1;
      case NotificationType.lowHealth:
        return 10;
      case NotificationType.projectStale:
        return 7;
    }
  }

  double _maxThreshold(NotificationType type) {
    switch (type) {
      case NotificationType.unpushedCommits:
        return 20;
      case NotificationType.staleChanges:
        return 14;
      case NotificationType.lowHealth:
        return 80;
      case NotificationType.projectStale:
        return 90;
    }
  }

  int _divisions(NotificationType type) {
    switch (type) {
      case NotificationType.unpushedCommits:
        return 19;
      case NotificationType.staleChanges:
        return 13;
      case NotificationType.lowHealth:
        return 7;
      case NotificationType.projectStale:
        return 10;
    }
  }

  String _thresholdLabel(NotificationRule rule) {
    switch (rule.type) {
      case NotificationType.unpushedCommits:
        return '${rule.threshold} commits';
      case NotificationType.staleChanges:
        return '${rule.threshold}d';
      case NotificationType.lowHealth:
        return '<${rule.threshold}';
      case NotificationType.projectStale:
        return '${rule.threshold}d';
    }
  }
}

class _NotificationHistoryCard extends StatelessWidget {
  final SentNotification notification;

  const _NotificationHistoryCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _typeColor(notification.type);
    final age = DateTime.now().difference(notification.sentAt);
    final ageStr = age.inDays > 0
        ? '${age.inDays}d ago'
        : age.inHours > 0
            ? '${age.inHours}h ago'
            : '${age.inMinutes}m ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notification.read
            ? Colors.transparent
            : color.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: notification.read
              ? cs.outline.withValues(alpha: 0.08)
              : color.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: notification.read
                  ? cs.outline.withValues(alpha: 0.2)
                  : color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            notification.read ? FontWeight.w400 : FontWeight.w600)),
                const SizedBox(height: 2),
                Text(notification.body,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(ageStr,
              style: AppTypography.mono(
                  fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Color _typeColor(NotificationType type) {
    switch (type) {
      case NotificationType.unpushedCommits:
        return AppColors.accent;
      case NotificationType.staleChanges:
        return AppColors.warning;
      case NotificationType.lowHealth:
        return AppColors.error;
      case NotificationType.projectStale:
        return const Color(0xFF8B5CF6);
    }
  }
}
