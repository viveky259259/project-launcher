import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'git_service.dart';
import 'health_service.dart';
import 'notification_service.dart';
import 'project_storage.dart';

/// Status of the background monitor
enum MonitorStatus { idle, checking, done }

/// Snapshot of the latest background check
class MonitorSnapshot {
  final DateTime checkedAt;
  final int projectsChecked;
  final int unhealthyCount;
  final int unpushedCount;
  final int uncommittedCount;
  final Duration elapsed;

  const MonitorSnapshot({
    required this.checkedAt,
    required this.projectsChecked,
    required this.unhealthyCount,
    required this.unpushedCount,
    required this.uncommittedCount,
    required this.elapsed,
  });
}

/// Background monitor that runs on app start and periodically checks
/// project health, git status, and fires notifications.
class BackgroundMonitor {
  static Timer? _timer;
  static MonitorStatus _status = MonitorStatus.idle;
  static MonitorSnapshot? _lastSnapshot;
  static int _checkProgress = 0;
  static int _checkTotal = 0;

  // Listeners for UI updates
  static final List<VoidCallback> _listeners = [];

  static MonitorStatus get status => _status;
  static MonitorSnapshot? get lastSnapshot => _lastSnapshot;
  static int get checkProgress => _checkProgress;
  static int get checkTotal => _checkTotal;

  /// Add a listener to be notified when status changes
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Start the background monitor.
  /// Runs an initial check immediately, then repeats on [interval].
  static void start({Duration interval = const Duration(minutes: 15)}) {
    if (_timer != null) return;

    log('[BackgroundMonitor] Starting with interval: ${interval.inMinutes}m');

    // Run first check after a short delay so the UI loads first
    Future.delayed(const Duration(seconds: 3), () => runCheck());

    _timer = Timer.periodic(interval, (_) => runCheck());
  }

  /// Stop the background monitor
  static void stop() {
    _timer?.cancel();
    _timer = null;
    log('[BackgroundMonitor] Stopped');
  }

  static bool get isRunning => _timer != null;

  /// Run a single background check across all projects.
  /// Updates health cache, collects git status, and fires notifications.
  static Future<void> runCheck() async {
    if (_status == MonitorStatus.checking) return; // already running

    _status = MonitorStatus.checking;
    _notifyListeners();

    final stopwatch = Stopwatch()..start();
    int unhealthy = 0;
    int unpushed = 0;
    int uncommitted = 0;

    try {
      final projects = await ProjectStorage.loadProjects();
      _checkTotal = projects.length;
      _checkProgress = 0;
      _notifyListeners();

      for (final project in projects) {
        // Refresh health score (will use cache if not expired)
        try {
          final health = await HealthService.getHealthScore(project.path);
          if (health.details.totalScore < 50) unhealthy++;
        } catch (_) {}

        // Check git status
        try {
          final isGit = await GitService.isGitRepository(project.path);
          if (isGit) {
            final unpushedCount =
                await GitService.getUnpushedCommitCount(project.path);
            if (unpushedCount > 0) unpushed++;

            final hasChanges =
                await GitService.hasUncommittedChanges(project.path);
            if (hasChanges) uncommitted++;
          }
        } catch (_) {}

        _checkProgress++;
        _notifyListeners();
      }

      stopwatch.stop();

      _lastSnapshot = MonitorSnapshot(
        checkedAt: DateTime.now(),
        projectsChecked: projects.length,
        unhealthyCount: unhealthy,
        unpushedCount: unpushed,
        uncommittedCount: uncommitted,
        elapsed: stopwatch.elapsed,
      );

      log('[BackgroundMonitor] Check complete: '
          '${projects.length} projects in ${stopwatch.elapsed.inSeconds}s — '
          '$unhealthy unhealthy, $unpushed unpushed, $uncommitted uncommitted');

      // Trigger notification checks with fresh data
      await NotificationService.checkAll();
    } catch (e) {
      log('[BackgroundMonitor] Error: $e');
    }

    _status = MonitorStatus.done;
    _checkProgress = 0;
    _checkTotal = 0;
    _notifyListeners();
  }
}
