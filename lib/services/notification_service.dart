import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:launcher_models/launcher_models.dart';
import 'git_service.dart';
import 'health_service.dart';
import 'project_storage.dart';

/// Types of notifications the system can send
enum NotificationType {
  unpushedCommits,
  staleChanges,
  lowHealth,
  projectStale,
}

/// A notification rule configuration
class NotificationRule {
  final NotificationType type;
  final bool enabled;
  final int threshold; // meaning varies by type

  const NotificationRule({
    required this.type,
    required this.enabled,
    this.threshold = 0,
  });

  factory NotificationRule.fromJson(Map<String, dynamic> json) =>
      NotificationRule(
        type: NotificationType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => NotificationType.unpushedCommits,
        ),
        enabled: json['enabled'] as bool? ?? true,
        threshold: json['threshold'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'enabled': enabled,
        'threshold': threshold,
      };

  NotificationRule copyWith({bool? enabled, int? threshold}) => NotificationRule(
        type: type,
        enabled: enabled ?? this.enabled,
        threshold: threshold ?? this.threshold,
      );

  String get label {
    switch (type) {
      case NotificationType.unpushedCommits:
        return 'Unpushed Commits';
      case NotificationType.staleChanges:
        return 'Stale Uncommitted Changes';
      case NotificationType.lowHealth:
        return 'Low Health Score';
      case NotificationType.projectStale:
        return 'Stale Projects';
    }
  }

  String get description {
    switch (type) {
      case NotificationType.unpushedCommits:
        return 'Notify when a project has $threshold+ unpushed commits';
      case NotificationType.staleChanges:
        return 'Notify when uncommitted changes sit for $threshold+ days';
      case NotificationType.lowHealth:
        return 'Notify when health score drops below $threshold';
      case NotificationType.projectStale:
        return 'Notify when no commits for $threshold+ days';
    }
  }

  IconLabel get iconLabel {
    switch (type) {
      case NotificationType.unpushedCommits:
        return const IconLabel('cloud_upload', 'Push');
      case NotificationType.staleChanges:
        return const IconLabel('edit_note', 'Commit');
      case NotificationType.lowHealth:
        return const IconLabel('health_and_safety', 'Health');
      case NotificationType.projectStale:
        return const IconLabel('schedule', 'Activity');
    }
  }
}

class IconLabel {
  final String icon;
  final String label;
  const IconLabel(this.icon, this.label);
}

/// A sent notification record
class SentNotification {
  final String title;
  final String body;
  final NotificationType type;
  final String? projectName;
  final DateTime sentAt;
  final bool read;

  const SentNotification({
    required this.title,
    required this.body,
    required this.type,
    this.projectName,
    required this.sentAt,
    this.read = false,
  });

  factory SentNotification.fromJson(Map<String, dynamic> json) =>
      SentNotification(
        title: json['title'] as String,
        body: json['body'] as String,
        type: NotificationType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => NotificationType.unpushedCommits,
        ),
        projectName: json['projectName'] as String?,
        sentAt: DateTime.parse(json['sentAt'] as String),
        read: json['read'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'type': type.name,
        'projectName': projectName,
        'sentAt': sentAt.toIso8601String(),
        'read': read,
      };
}

class NotificationService {
  static Timer? _checkTimer;
  static bool _isRunning = false;
  static final List<SentNotification> _history = [];
  static List<NotificationRule> _rules = [];

  // Cooldown: don't re-notify the same project+type within this window
  static final Map<String, DateTime> _cooldowns = {};
  static const _cooldownDuration = Duration(hours: 4);

  static bool get isRunning => _isRunning;
  static List<SentNotification> get history => List.unmodifiable(_history);
  static List<NotificationRule> get rules => List.unmodifiable(_rules);
  static int get unreadCount => _history.where((n) => !n.read).length;

  /// Default rules
  static final List<NotificationRule> _defaultRules = [
    const NotificationRule(
      type: NotificationType.unpushedCommits,
      enabled: true,
      threshold: 3,
    ),
    const NotificationRule(
      type: NotificationType.staleChanges,
      enabled: true,
      threshold: 3,
    ),
    const NotificationRule(
      type: NotificationType.lowHealth,
      enabled: true,
      threshold: 40,
    ),
    const NotificationRule(
      type: NotificationType.projectStale,
      enabled: false,
      threshold: 30,
    ),
  ];

  /// Initialize and start the notification service
  static Future<void> initialize() async {
    await _loadRules();
    await _loadHistory();
  }

  /// Start background monitoring
  static void start({Duration interval = const Duration(minutes: 30)}) {
    if (_isRunning) return;
    _isRunning = true;
    _checkTimer = Timer.periodic(interval, (_) => checkAll());
    // Run first check after a short delay
    Future.delayed(const Duration(seconds: 10), checkAll);
  }

  /// Stop background monitoring
  static void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _isRunning = false;
  }

  /// Run all notification checks
  static Future<void> checkAll() async {
    final projects = await ProjectStorage.loadProjects();
    final healthCache = await HealthService.loadCache();

    for (final project in projects) {
      for (final rule in _rules) {
        if (!rule.enabled) continue;

        switch (rule.type) {
          case NotificationType.unpushedCommits:
            await _checkUnpushed(project.name, project.path, rule.threshold);
          case NotificationType.staleChanges:
            await _checkStaleChanges(
                project.name, project.path, rule.threshold, healthCache);
          case NotificationType.lowHealth:
            _checkLowHealth(
                project.name, project.path, rule.threshold, healthCache);
          case NotificationType.projectStale:
            _checkProjectStale(
                project.name, project.path, rule.threshold, healthCache);
        }
      }
    }
  }

  static Future<void> _checkUnpushed(
      String name, String path, int threshold) async {
    final isGit = await GitService.isGitRepository(path);
    if (!isGit) return;

    final count = await GitService.getUnpushedCommitCount(path);
    if (count >= threshold) {
      await _notify(
        title: '$name: $count unpushed commits',
        body: 'Push your work to avoid data loss.',
        type: NotificationType.unpushedCommits,
        projectName: name,
      );
    }
  }

  static Future<void> _checkStaleChanges(String name, String path,
      int threshold, Map<String, CachedHealthScore> healthCache) async {
    final isGit = await GitService.isGitRepository(path);
    if (!isGit) return;

    final hasChanges = await GitService.hasUncommittedChanges(path);
    if (!hasChanges) return;

    final cached = healthCache[path];
    if (cached == null) return;

    if (cached.details.lastCommitDate == null) return;

    final days = DateTime.now().difference(cached.details.lastCommitDate!).inDays;
    if (days >= threshold) {
      await _notify(
        title: '$name: uncommitted changes for ${days}d',
        body: 'Commit or stash your changes.',
        type: NotificationType.staleChanges,
        projectName: name,
      );
    }
  }

  static void _checkLowHealth(String name, String path, int threshold,
      Map<String, CachedHealthScore> healthCache) {
    final cached = healthCache[path];
    if (cached == null) return;

    final score = cached.details.totalScore;
    if (score < threshold) {
      _notify(
        title: '$name: health score $score/100',
        body: 'This project needs attention.',
        type: NotificationType.lowHealth,
        projectName: name,
      );
    }
  }

  static void _checkProjectStale(String name, String path, int threshold,
      Map<String, CachedHealthScore> healthCache) {
    final cached = healthCache[path];
    if (cached == null) return;

    if (cached.details.lastCommitDate == null) return;

    final days = DateTime.now().difference(cached.details.lastCommitDate!).inDays;
    if (days >= threshold) {
      _notify(
        title: '$name: no commits for ${days}d',
        body: 'Is this project still active?',
        type: NotificationType.projectStale,
        projectName: name,
      );
    }
  }

  /// Send a native notification
  static Future<void> _notify({
    required String title,
    required String body,
    required NotificationType type,
    String? projectName,
  }) async {
    // Check cooldown
    final key = '${type.name}:${projectName ?? "global"}';
    final lastSent = _cooldowns[key];
    if (lastSent != null &&
        DateTime.now().difference(lastSent) < _cooldownDuration) {
      return;
    }

    // Send native notification
    await _sendNativeNotification(title, body);

    // Record
    final notification = SentNotification(
      title: title,
      body: body,
      type: type,
      projectName: projectName,
      sentAt: DateTime.now(),
    );
    _history.insert(0, notification);
    if (_history.length > 50) _history.removeLast();
    _cooldowns[key] = DateTime.now();

    await _saveHistory();
  }

  static Future<void> _sendNativeNotification(
      String title, String body) async {
    if (Platform.isMacOS) {
      final safeTitle = title.replaceAll('"', '\\"');
      final safeBody = body.replaceAll('"', '\\"');
      await Process.run('osascript', [
        '-e',
        'display notification "$safeBody" with title "Project Launcher" subtitle "$safeTitle"',
      ]);
    } else if (Platform.isLinux) {
      await Process.run('notify-send', [
        'Project Launcher: $title',
        body,
      ]);
    }
    // Windows: would use PowerShell toast notification
  }

  /// Update a notification rule
  static Future<void> updateRule(NotificationRule rule) async {
    final idx = _rules.indexWhere((r) => r.type == rule.type);
    if (idx >= 0) {
      _rules[idx] = rule;
    } else {
      _rules.add(rule);
    }
    await _saveRules();
  }

  /// Mark all notifications as read
  static Future<void> markAllRead() async {
    for (var i = 0; i < _history.length; i++) {
      if (!_history[i].read) {
        _history[i] = SentNotification(
          title: _history[i].title,
          body: _history[i].body,
          type: _history[i].type,
          projectName: _history[i].projectName,
          sentAt: _history[i].sentAt,
          read: true,
        );
      }
    }
    await _saveHistory();
  }

  /// Clear notification history
  static Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
  }

  // ── Persistence ──

  static Future<void> _loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('notificationRules');
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>;
        _rules = list
            .map((e) => NotificationRule.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _rules = List.from(_defaultRules);
      }
    } catch (_) {
      _rules = List.from(_defaultRules);
    }
  }

  static Future<void> _saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'notificationRules', jsonEncode(_rules.map((r) => r.toJson()).toList()));
  }

  static Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('notificationHistory');
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>;
        _history.clear();
        _history.addAll(list
            .map((e) =>
                SentNotification.fromJson(e as Map<String, dynamic>))
            .toList());
      }
    } catch (_) {}
  }

  static Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notificationHistory',
        jsonEncode(_history.map((n) => n.toJson()).toList()));
  }
}
