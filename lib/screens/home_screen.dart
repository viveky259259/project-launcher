import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:launcher_native/launcher_native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:launcher_models/launcher_models.dart';
import '../services/git_service.dart';
import '../services/project_storage.dart';
import '../services/launcher_service.dart';
import '../services/platform_helper.dart';
import '../services/project_scanner.dart';
import '../dialogs/scan_dialog.dart';
import '../services/health_service.dart';
import '../services/premium_service.dart';
import '../services/project_type_detector.dart';
import '../main.dart';
import 'package:launcher_theme/launcher_theme.dart';
import '../widgets/home/project_card.dart';
import '../widgets/home/filter_bar.dart';
import '../widgets/home/side_panel.dart';
import '../widgets/home/status_bar.dart';
import '../widgets/theme_switcher.dart';
import 'year_review_screen.dart';
import 'health_screen.dart';
import 'insights_screen.dart';
import 'plugins_screen.dart';
import 'referral_screen.dart';
import 'pro_screen.dart';
import 'project_settings_screen.dart';
import 'onboarding_screen.dart';
import 'subscription_screen.dart';
import '../services/api_server.dart';
import '../services/notification_service.dart';
import '../services/background_monitor.dart';
import 'notifications_screen.dart';
import 'dashboard_customize_screen.dart';
import '../services/dashboard_config.dart';
import '../services/ai_service.dart';
import '../services/version_detector.dart';
import '../services/export_service.dart';
import '../services/fresh_push_service.dart';
import '../services/cli_install_service.dart';
import '../dialogs/export_dialog.dart';
import '../widgets/home/cli_install_banner.dart';
import '../widgets/home/grid_project_card.dart';
import '../widgets/home/header_widgets.dart';

enum SortMode { lastOpened, name, lastChanged }

enum ViewMode { list, folder }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Project> _projects = [];
  List<String> _allTags = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  SortMode _sortMode = SortMode.lastOpened;
  ViewMode _viewMode = ViewMode.list;
  String _searchQuery = '';
  String? _selectedTag;
  final _searchController = TextEditingController();
  HealthFilter _healthFilter = HealthFilter.all;
  StalenessFilter _stalenessFilter = StalenessFilter.all;
  Map<String, CachedHealthScore> _healthScores = {};
  bool _showThemeSwitcher = false;
  DateTime? _lastScanTime;
  final _searchFocusNode = FocusNode();
  bool _isPro = false;
  Map<String, ProjectStack> _projectStacks = {};
  ProjectType? _selectedProjectType;
  ActivityFilter _activityFilter = ActivityFilter.all;
  GitFilter _gitFilter = GitFilter.all;
  Map<String, String> _branchNames = {};
  Map<String, DateTime?> _lastCommitDates = {};
  bool _pinnedCollapsed = false;
  Map<String, bool> _projectAIInsights = {};
  Map<String, String?> _projectVersions = {};
  Map<String, int> _unreleasedCommits = {};
  StreamSubscription<FileSystemEvent>? _projectsFileWatcher;
  bool _showCliInstallBanner = false;

  ProjectLauncherAppState? get _appState => ProjectLauncherApp.of(context);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadProjects();
    _loadHealthScores();
    _loadProStatus();
    _loadAIInsightsFlags();
    _checkFirstRun();
    _checkCliInstall();
    _watchProjectsFile();
    BackgroundMonitor.addListener(_onMonitorUpdate);
    // No periodic refresh — data loads once on init, then on user action
    // (scan, add, remove, pin, tag edit, returning from settings)
  }

  void _onMonitorUpdate() {
    if (mounted) {
      setState(() {});
      // Refresh health scores when background check finishes
      if (BackgroundMonitor.status == MonitorStatus.done) {
        _loadHealthScores();
      }
    }
  }

  Future<void> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOnboarded = prefs.getBool('hasCompletedOnboarding') ?? false;
    if (hasOnboarded) return;

    // Wait for projects to load
    final projects = await ProjectStorage.loadProjects();
    if (projects.isEmpty && mounted) {
      // Mark onboarding as done so we don't re-trigger
      await prefs.setBool('hasCompletedOnboarding', true);
      // Auto-open the scan dialog after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scanForProjects();
      });
    } else {
      // Already has projects, just mark as done
      await prefs.setBool('hasCompletedOnboarding', true);
    }
  }

  Future<void> _checkCliInstall() async {
    final shouldPrompt = await CliInstallService.shouldPrompt();
    if (mounted && shouldPrompt) {
      setState(() => _showCliInstallBanner = true);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _projectsFileWatcher?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    BackgroundMonitor.removeListener(_onMonitorUpdate);
    super.dispose();
  }

  Future<void> _loadProStatus() async {
    final pro = await PremiumService.isPro();
    if (mounted) setState(() => _isPro = pro);
  }

  // --- Data loading ---

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final sortIndex = prefs.getInt('sortMode') ?? 0;
    final viewIndex = prefs.getInt('viewMode') ?? 0;
    final pinnedCollapsed = prefs.getBool('pinnedCollapsed') ?? false;
    if (mounted) {
      setState(() {
        _sortMode = SortMode.values[sortIndex];
        _viewMode = ViewMode.values[viewIndex];
        _pinnedCollapsed = pinnedCollapsed;
      });
    }
  }

  Future<void> _loadProjects() async {
    final projects = await ProjectStorage.loadProjects();
    final tags = await ProjectStorage.getAllTags();
    // Detect project stacks for new projects only
    final stacks = Map<String, ProjectStack>.from(_projectStacks);
    for (final p in projects) {
      if (!stacks.containsKey(p.path)) {
        stacks[p.path] = ProjectStack.detect(p.path);
      }
    }
    if (mounted) {
      setState(() {
        _projects = projects;
        _allTags = tags;
        _projectStacks = stacks;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHealthScores() async {
    final projects = await ProjectStorage.loadProjects();
    final scores = await HealthService.getHealthScores(
      projects.map((p) => p.path).toList(),
    );
    // Load branch names and last commit dates for git repos
    final branches = <String, String>{};
    final commitDates = <String, DateTime?>{};
    for (final p in projects) {
      final branch = await GitService.getCurrentBranch(p.path);
      if (branch != null) branches[p.path] = branch;
      final changedDate = await GitService.getLastChangedDate(p.path);
      commitDates[p.path] = changedDate;
    }
    if (mounted) {
      setState(() {
        _healthScores = scores;
        _branchNames = branches;
        _lastCommitDates = commitDates;
      });
    }
  }

  Future<void> _loadAIInsightsFlags() async {
    final projects = await ProjectStorage.loadProjects();
    final flags = <String, bool>{};
    final versions = <String, String?>{};
    final unreleased = <String, int>{};
    for (final p in projects) {
      flags[p.path] = await AIService.hasInsights(p.path);
      final info = await VersionDetector.detect(p.path);
      versions[p.path] = info.version;
      unreleased[p.path] = info.unreleasedCommits;
    }
    if (mounted) {
      setState(() {
        _projectAIInsights = flags;
        _projectVersions = versions;
        _unreleasedCommits = unreleased;
      });
    }
  }

  /// Watch ~/.project_launcher/projects.json for external modifications
  /// (e.g., from the `addproject` CLI command).
  void _watchProjectsFile() {
    try {
      final filePath =
          '${PlatformHelper.dataDir}${Platform.pathSeparator}projects.json';
      final file = File(filePath);
      if (!file.existsSync()) {
        // File doesn't exist yet — watch the directory instead
        final dir = Directory(PlatformHelper.dataDir);
        if (!dir.existsSync()) return;
        _projectsFileWatcher = dir
            .watch(events: FileSystemEvent.create | FileSystemEvent.modify)
            .listen((event) {
              if (event.path.endsWith('projects.json')) {
                AppLogger.info(
                  'FileWatch',
                  'projects.json changed (directory event), reloading',
                );
                _loadProjects();
                _loadHealthScores();
                _loadAIInsightsFlags();
              }
            });
        AppLogger.info(
          'FileWatch',
          'Watching directory for projects.json creation',
        );
        return;
      }
      _projectsFileWatcher = file.watch(events: FileSystemEvent.modify).listen((
        event,
      ) {
        AppLogger.info(
          'FileWatch',
          'projects.json modified externally, reloading',
        );
        _loadProjects();
        _loadHealthScores();
        _loadAIInsightsFlags();
      });
      AppLogger.info('FileWatch', 'Watching projects.json for changes');
    } catch (e) {
      AppLogger.warn('FileWatch', 'Could not set up file watcher: $e');
    }
  }

  // --- Filtering & sorting ---

  List<Project> get _filteredProjects {
    var filtered = _projects.toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (p) =>
                p.name.toLowerCase().contains(query) ||
                p.path.toLowerCase().contains(query) ||
                p.tags.any((t) => t.toLowerCase().contains(query)) ||
                (p.notes?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    if (_selectedTag != null) {
      filtered = filtered.where((p) => p.tags.contains(_selectedTag)).toList();
    }

    if (_healthFilter != HealthFilter.all) {
      filtered = filtered.where((p) {
        final health = _healthScores[p.path];
        if (health == null) return false;
        switch (_healthFilter) {
          case HealthFilter.healthy:
            return health.details.category == HealthCategory.healthy;
          case HealthFilter.needsAttention:
            return health.details.category == HealthCategory.needsAttention;
          case HealthFilter.critical:
            return health.details.category == HealthCategory.critical;
          default:
            return true;
        }
      }).toList();
    }

    if (_stalenessFilter == StalenessFilter.staleOnly) {
      filtered = filtered.where((p) {
        final health = _healthScores[p.path];
        if (health == null) return false;
        return health.staleness != StalenessLevel.fresh;
      }).toList();
    }

    if (_selectedProjectType != null) {
      filtered = filtered.where((p) {
        final stack = _projectStacks[p.path];
        return stack != null && stack.contains(_selectedProjectType!);
      }).toList();
    }

    if (_activityFilter != ActivityFilter.all) {
      filtered = filtered.where((p) {
        final health = _healthScores[p.path];
        final lastCommit = health?.details.lastCommitDate;
        if (lastCommit == null) return _activityFilter == ActivityFilter.older;

        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfThisWeek = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        final startOfLastWeek = startOfThisWeek.subtract(
          const Duration(days: 7),
        );
        final startOfThisMonth = DateTime(now.year, now.month, 1);
        final startOfLastMonth = DateTime(now.year, now.month - 1, 1);

        switch (_activityFilter) {
          case ActivityFilter.thisWeek:
            return lastCommit.isAfter(startOfThisWeek);
          case ActivityFilter.lastWeek:
            return lastCommit.isAfter(startOfLastWeek) &&
                lastCommit.isBefore(startOfThisWeek);
          case ActivityFilter.thisMonth:
            return lastCommit.isAfter(startOfThisMonth);
          case ActivityFilter.lastMonth:
            return lastCommit.isAfter(startOfLastMonth) &&
                lastCommit.isBefore(startOfThisMonth);
          case ActivityFilter.older:
            return lastCommit.isBefore(startOfLastMonth);
          default:
            return true;
        }
      }).toList();
    }

    if (_gitFilter != GitFilter.all) {
      filtered = filtered.where((p) {
        final isGit = _isGitRepo(p.path);
        final unpushed = _hasUnpushed(p.path);
        switch (_gitFilter) {
          case GitFilter.gitOnly:
            return isGit;
          case GitFilter.noGit:
            return !isGit;
          case GitFilter.unpushed:
            return unpushed;
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  List<Project> get _sortedProjects {
    final sorted = List<Project>.from(_filteredProjects);

    if (_sortMode == SortMode.name) {
      sorted.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else if (_sortMode == SortMode.lastChanged) {
      sorted.sort((a, b) {
        final aCommit = _lastCommitDates[a.path];
        final bCommit = _lastCommitDates[b.path];
        // Projects with commits sort before those without
        if (aCommit == null && bCommit == null) return 0;
        if (aCommit == null) return 1;
        if (bCommit == null) return -1;
        return bCommit.compareTo(aCommit);
      });
    } else {
      sorted.sort((a, b) {
        final aTime = a.lastOpenedAt ?? a.addedAt;
        final bTime = b.lastOpenedAt ?? b.addedAt;
        return bTime.compareTo(aTime);
      });
    }

    // Pinned-first only for Recent and A-Z sorts, not for Last Changed
    if (_sortMode != SortMode.lastChanged) {
      sorted.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return 0;
      });
    }

    return sorted;
  }

  Map<String, List<Project>> get _groupedProjects {
    final groups = <String, List<Project>>{};
    for (final project in _sortedProjects) {
      final parentName = PlatformHelper.parentDirName(project.path);
      groups.putIfAbsent(parentName, () => []).add(project);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (var k in sortedKeys) k: groups[k]!};
  }

  // --- Health counts ---

  int get _healthyCount => _healthScores.values
      .where((s) => s.details.category == HealthCategory.healthy)
      .length;

  int get _needsAttentionCount => _healthScores.values
      .where((s) => s.details.category == HealthCategory.needsAttention)
      .length;

  Map<ActivityFilter, int> get _activityCounts {
    final counts = <ActivityFilter, int>{};
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfThisWeek = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);

    int thisWeek = 0, lastWeek = 0, thisMonth = 0, lastMonth = 0, older = 0;

    for (final p in _projects) {
      final health = _healthScores[p.path];
      final lastCommit = health?.details.lastCommitDate;
      if (lastCommit == null) {
        older++;
        continue;
      }
      if (lastCommit.isAfter(startOfThisWeek)) {
        thisWeek++;
      } else if (lastCommit.isAfter(startOfLastWeek)) {
        lastWeek++;
      }
      if (lastCommit.isAfter(startOfThisMonth)) {
        thisMonth++;
      } else if (lastCommit.isAfter(startOfLastMonth)) {
        lastMonth++;
      } else {
        older++;
      }
    }

    counts[ActivityFilter.all] = _projects.length;
    counts[ActivityFilter.thisWeek] = thisWeek;
    counts[ActivityFilter.lastWeek] = lastWeek;
    counts[ActivityFilter.thisMonth] = thisMonth;
    counts[ActivityFilter.lastMonth] = lastMonth;
    counts[ActivityFilter.older] = older;
    return counts;
  }

  int get _unpushedCount {
    int count = 0;
    for (final p in _projects) {
      final health = _healthScores[p.path];
      if (health != null && !health.details.noUnpushedCommits) {
        count++;
      }
    }
    return count;
  }

  bool _isGitRepo(String path) {
    final health = _healthScores[path];
    return health != null && health.details.gitScore > 0;
  }

  bool _hasUnpushed(String path) {
    final health = _healthScores[path];
    return health != null && !health.details.noUnpushedCommits;
  }

  List<double> get _weeklyActivity {
    final now = DateTime.now();
    final counts = List<double>.filled(7, 0);
    for (final score in _healthScores.values) {
      final lastCommit = score.details.lastCommitDate;
      if (lastCommit == null) continue;
      final daysAgo = now.difference(lastCommit).inDays;
      if (daysAgo >= 0 && daysAgo < 7) {
        counts[6 - daysAgo] += 1;
      }
    }
    return counts;
  }

  // --- Actions ---

  Future<void> _openInTerminal(Project project) async {
    await ProjectStorage.updateLastOpened(project.path);
    await LauncherService.openInTerminal(project.path);
    _loadProjects();
  }

  Future<void> _openInVSCode(Project project) async {
    await ProjectStorage.updateLastOpened(project.path);
    await LauncherService.openInVSCode(project.path);
    _loadProjects();
  }

  Future<void> _removeProject(Project project) async {
    await ProjectStorage.removeProject(project.path);
    _loadProjects();
  }

  Future<void> _togglePin(Project project) async {
    await ProjectStorage.togglePinned(project.path);
    _loadProjects();
  }

  Future<void> _editTags(Project project) async {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: project.tags.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Tags for ${project.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Tags (comma separated)',
                  hintText: 'work, flutter, personal',
                  prefixIcon: const Icon(Icons.label_rounded, size: 18),
                  filled: true,
                  fillColor: cs.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                style: AppTypography.mono(fontSize: 13, color: cs.onSurface),
              ),
              if (_allTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Existing tags:',
                  style: Theme.of(ctx).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _allTags
                      .map(
                        (tag) => InkWell(
                          onTap: () {
                            final current = controller.text;
                            if (current.isEmpty) {
                              controller.text = tag;
                            } else if (!current
                                .split(',')
                                .map((t) => t.trim())
                                .contains(tag)) {
                              controller.text = '$current, $tag';
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              tag,
                              style: Theme.of(ctx).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final tags = result
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      await ProjectStorage.updateTags(project.path, tags);
      _loadProjects();
    }
  }

  Future<void> _editNotes(Project project) async {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: project.notes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Notes for ${project.name}'),
        content: SizedBox(
          width: 500,
          height: 200,
          child: TextField(
            controller: controller,
            maxLines: 10,
            minLines: 5,
            decoration: InputDecoration(
              hintText: 'Add notes, TODOs, or reminders...',
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            style: AppTypography.mono(fontSize: 13, color: cs.onSurface),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          if (project.notes != null && project.notes!.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: Text('Clear', style: TextStyle(color: AppColors.error)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await ProjectStorage.updateNotes(
        project.path,
        result.isEmpty ? null : result,
      );
      _loadProjects();
    }
  }

  Future<void> _addProjectManually() async {
    // Use file picker to browse for a directory
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select a project folder',
    );

    if (result != null && result.isNotEmpty) {
      final dir = Directory(result);
      if (await dir.exists()) {
        final name = PlatformHelper.basename(result);
        final project = Project(
          name: name,
          path: result,
          addedAt: DateTime.now(),
        );
        await ProjectStorage.addProject(project);
        _loadProjects();
        _loadHealthScores();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Directory does not exist')),
          );
        }
      }
    }
  }

  void _showYearInReview() async {
    final isPro = await PremiumService.isPro();
    if (!isPro) {
      if (mounted) _showUpgradePrompt('Year in Review');
      return;
    }
    if (mounted) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const YearReviewScreen()));
    }
  }

  void _showUpgradePrompt(String featureName) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFFD700)),
            SizedBox(width: 8),
            Text('Pro Feature'),
          ],
        ),
        content: Text(
          '$featureName is a Pro feature. Upgrade to unlock it and all other premium features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Maybe Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showProScreen();
            },
            child: const Text('View Pro'),
          ),
        ],
      ),
    );
  }

  void _showProScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          onStatusChanged: () {
            _loadProStatus();
            _appState?.refreshPremiumStatus();
          },
        ),
      ),
    );
  }

  void _showSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubscriptionScreen(
          onStatusChanged: () {
            _loadProStatus();
            _appState?.refreshPremiumStatus();
          },
        ),
      ),
    );
  }

  void _showHealthDashboard() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HealthScreen()));
  }

  void _showInsights() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const InsightsScreen()));
  }

  void _showReferrals() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReferralScreen()));
  }

  void _showApiSettings() {
    final cs = Theme.of(context).colorScheme;
    final portController = TextEditingController(text: '${ApiServer.port}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cs.surface,
          title: Row(
            children: [
              Icon(Icons.api_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              const Text('Local API Server'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expose project data via a local REST API for scripts, '
                'Alfred workflows, Raycast extensions, and other tools.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Server Status',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                  ),
                  Switch(
                    value: ApiServer.isRunning,
                    activeThumbColor: AppColors.accent,
                    onChanged: (enabled) async {
                      if (enabled) {
                        final port = int.tryParse(portController.text) ?? 9847;
                        await ApiServer.start(port: port);
                      } else {
                        await ApiServer.stop();
                      }
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('apiServerEnabled', enabled);
                      if (enabled) {
                        await prefs.setInt('apiServerPort', ApiServer.port);
                      }
                      setDialogState(() {});
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portController,
                decoration: InputDecoration(
                  labelText: 'Port',
                  hintText: '9847',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  prefixIcon: const Icon(Icons.numbers, size: 18),
                  suffixText: ApiServer.isRunning ? 'In use' : null,
                ),
                keyboardType: TextInputType.number,
                enabled: !ApiServer.isRunning,
              ),
              if (ApiServer.isRunning) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Base URL',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        'http://localhost:${ApiServer.port}/api',
                        style: AppTypography.mono(
                          fontSize: 12,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Try it:',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        'curl localhost:${ApiServer.port}/api/projects',
                        style: AppTypography.mono(
                          fontSize: 11,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ExportDialog(projects: _projects),
    );
  }

  void _openProjectSettings(Project project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectSettingsScreen(
          project: project,
          healthScore: _healthScores[project.path],
          onSaved: () {
            _loadProjects();
            _loadHealthScores();
          },
          onRemoved: () {
            _loadProjects();
            _loadHealthScores();
          },
          onOpenTerminal: () => _openInTerminal(project),
          onOpenVSCode: () => _openInVSCode(project),
          onTogglePin: () {
            _togglePin(project);
            Navigator.of(context).pop();
            _openProjectSettings(project);
          },
        ),
      ),
    );
  }

  Future<void> _scanForProjects() async {
    final result = await showDialog<ScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ScanDialog(),
    );

    if (result != null && result.newlyAdded > 0) {
      _loadProjects();
      _loadHealthScores();
      setState(() => _lastScanTime = DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${result.newlyAdded} new project${result.newlyAdded == 1 ? '' : 's'}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _saveSortPreference(SortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sortMode', mode.index);
  }

  void _saveViewPreference(ViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('viewMode', mode.index);
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pinnedProjects = _sortedProjects.where((p) => p.isPinned).toList();
    final recentProjects = _sortedProjects;
    final appState = _appState;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              Column(
                children: [
                  // Top bar with macOS traffic lights
                  _buildTopBar(cs),

                  // Filter bar
                  FilterBar(
                    healthFilter: _healthFilter,
                    stalenessFilter: _stalenessFilter,
                    sortMode: _sortMode,
                    onSortChanged: (mode) {
                      setState(() => _sortMode = mode);
                      _saveSortPreference(mode);
                    },
                    onHealthFilterChanged: (f) =>
                        setState(() => _healthFilter = f),
                    onStalenessFilterChanged: (f) =>
                        setState(() => _stalenessFilter = f),
                    viewModeIndex: _viewMode == ViewMode.list ? 0 : 1,
                    onViewModeChanged: (i) {
                      final newMode = i == 0 ? ViewMode.list : ViewMode.folder;
                      setState(() => _viewMode = newMode);
                      _saveViewPreference(newMode);
                    },
                    allTags: _allTags,
                    selectedTag: _selectedTag,
                    onTagChanged: (tag) => setState(() => _selectedTag = tag),
                    availableProjectTypes: _projectStacks.values
                        .expand((s) => s.all)
                        .where((t) => t != ProjectType.unknown)
                        .toSet(),
                    selectedProjectType: _selectedProjectType,
                    onProjectTypeChanged: (type) =>
                        setState(() => _selectedProjectType = type),
                    activityFilter: _activityFilter,
                    onActivityFilterChanged: (f) =>
                        setState(() => _activityFilter = f),
                    activityCounts: _activityCounts,
                    gitFilter: _gitFilter,
                    onGitFilterChanged: (f) => setState(() => _gitFilter = f),
                    unpushedCount: _unpushedCount,
                  ),

                  // Main content
                  Expanded(
                    child: Row(
                      children: [
                        // Project list
                        Expanded(
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.accent,
                                  ),
                                )
                              : _projects.isEmpty
                              ? OnboardingScreen(
                                  onStartScan: _scanForProjects,
                                  onAddManually: _addProjectManually,
                                )
                              : _sortedProjects.isEmpty
                              ? _buildNoResults()
                              : _viewMode == ViewMode.folder
                              ? _buildGridView()
                              : _buildProjectList(
                                  pinnedProjects,
                                  recentProjects,
                                ),
                        ),

                        // Right side panel
                        if (_projects.isNotEmpty)
                          HomeSidePanel(
                            totalProjects: _projects.length,
                            healthyCount: _healthyCount,
                            needsAttentionCount: _needsAttentionCount,
                            isPro: _isPro,
                            onYearReviewTap: _showYearInReview,
                            onHealthTap: _showHealthDashboard,
                            onInsightsTap: _showInsights,
                            weeklyActivity: _weeklyActivity,
                            activityCounts: _activityCounts,
                          ),
                      ],
                    ),
                  ),

                  // Upgrade banner for free users
                  if (!_isPro && _projects.isNotEmpty) _buildUpgradeBanner(cs),

                  // Status bar
                  StatusBar(
                    lastScanTime: _lastScanTime,
                    unreleasedCount: _unreleasedCommits.values
                        .where((c) => c > 0)
                        .length,
                    readyToShipCount: _projects.where((p) {
                      final version = _projectVersions[p.path];
                      final unreleased = _unreleasedCommits[p.path] ?? 0;
                      return version != null && unreleased == 0;
                    }).length,
                  ),
                ],
              ),

              // Theme switcher overlay
              if (_showThemeSwitcher)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _showThemeSwitcher = false),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(top: 56, right: 16),
                      child: GestureDetector(
                        onTap: () {}, // Absorb taps on the panel itself
                        child: ThemeSwitcherPanel(
                          currentTheme: appState?.currentTheme ?? AppTheme.dark,
                          currentSkin:
                              appState?.currentSkin ?? const DefaultSkin(),
                          allSkins: ProjectLauncherAppState.allSkins,
                          unlockedThemes: appState?.unlockedThemes ?? [],
                          isPro: _isPro,
                          onThemeChanged: (theme) {
                            appState?.setTheme(theme);
                            setState(() => _showThemeSwitcher = false);
                          },
                          onSkinChanged: (skin) {
                            appState?.setSkin(skin);
                            setState(() {});
                          },
                          onClose: () =>
                              setState(() => _showThemeSwitcher = false),
                          onEarnThemes: () {
                            setState(() => _showThemeSwitcher = false);
                            _showReferrals();
                          },
                          onUnlockWithPro: () {
                            setState(() => _showThemeSwitcher = false);
                            _showProScreen();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // macOS drag area + branding
          const SizedBox(width: 68), // space for native traffic lights
          // App branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.1),
                  const Color(0xFFE879F9).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.rocket_launch_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Project Browser',
                  style: AppTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Search bar — expands to fill
          Expanded(
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      style: AppTypography.inter(
                        fontSize: 13,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search projects...',
                        hintStyle: AppTypography.inter(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '\u2318K',
                      style: AppTypography.mono(
                        fontSize: 10,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Syncing indicator
          if (BackgroundMonitor.status == MonitorStatus.checking)
            SyncingPill(
              progress: BackgroundMonitor.checkProgress,
              total: BackgroundMonitor.checkTotal,
            ),

          if (BackgroundMonitor.status == MonitorStatus.checking)
            const SizedBox(width: 8),

          // Divider
          Container(
            width: 1,
            height: 24,
            color: cs.outline.withValues(alpha: 0.1),
          ),

          const SizedBox(width: 8),

          // Action buttons — compact with hover tooltips
          HeaderButton(
            icon: Icons.radar_rounded,
            tooltip: 'Scan for projects',
            onPressed: _scanForProjects,
          ),
          HeaderButton(
            icon: Icons.add_rounded,
            tooltip: 'Add project',
            onPressed: _addProjectManually,
          ),

          const SizedBox(width: 4),

          // Divider
          Container(
            width: 1,
            height: 24,
            color: cs.outline.withValues(alpha: 0.1),
          ),

          const SizedBox(width: 4),

          // Pro badge or upgrade
          if (_isPro)
            _buildProBadge()
          else
            HeaderButton(
              icon: Icons.workspace_premium_rounded,
              tooltip: 'Upgrade to Pro',
              onPressed: _showSubscription,
              accentColor: const Color(0xFFFFD700),
            ),

          // Plugins
          HeaderButton(
            icon: Icons.extension_rounded,
            tooltip: 'Plugins',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PluginsScreen())),
          ),

          // API Server
          HeaderButton(
            icon: ApiServer.isRunning ? Icons.api_rounded : Icons.api_outlined,
            tooltip: ApiServer.isRunning
                ? 'API running on :${ApiServer.port}'
                : 'API Server (off)',
            onPressed: _showApiSettings,
            accentColor: ApiServer.isRunning ? AppColors.success : null,
          ),

          // Notifications
          Stack(
            children: [
              HeaderButton(
                icon: NotificationService.isRunning
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    )
                    .then((_) => setState(() {})),
              ),
              if (NotificationService.unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${NotificationService.unreadCount}',
                        style: AppTypography.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Customize Dashboard
          HeaderButton(
            icon: Icons.dashboard_customize_rounded,
            tooltip: 'Customize Dashboard',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    DashboardCustomizeScreen(onSaved: () => setState(() {})),
              ),
            ),
          ),

          // Export all projects as zip
          HeaderButton(
            icon: Icons.archive_rounded,
            tooltip: 'Export projects as ZIP',
            onPressed: _showExportDialog,
          ),

          // CLI Install
          HeaderButton(
            icon: Icons.terminal_rounded,
            tooltip: _showCliInstallBanner
                ? 'Install plauncher CLI'
                : 'plauncher CLI',
            onPressed: () async {
              final installed = await CliInstallService.isInstalled();
              if (installed) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('plauncher CLI is installed'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                // Reset "don't ask" and show banner
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('cli_install_dont_ask');
                if (mounted) setState(() => _showCliInstallBanner = true);
              }
            },
          ),

          // Settings
          HeaderButton(
            icon: Icons.palette_outlined,
            tooltip: 'Theme',
            onPressed: () =>
                setState(() => _showThemeSwitcher = !_showThemeSwitcher),
          ),
        ],
      ),
    );
  }

  Widget _buildProBadge() {
    return GestureDetector(
      onTap: _showSubscription,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium,
                size: 12,
                color: Colors.black87,
              ),
              const SizedBox(width: 4),
              Text(
                'PRO',
                style: AppTypography.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReleasePulse(ColorScheme cs) {
    final projectsWithUnreleased = _unreleasedCommits.entries
        .where((e) => e.value > 0)
        .toList();
    if (projectsWithUnreleased.isEmpty) return const SizedBox.shrink();

    // Find most urgent project: highest unreleased_commits x days_since_last_release
    String? urgentProjectPath;
    double highestUrgency = 0;
    for (final entry in projectsWithUnreleased) {
      final lastCommit = _lastCommitDates[entry.key];
      final daysSinceCommit = lastCommit != null
          ? DateTime.now().difference(lastCommit).inDays.clamp(1, 9999)
          : 1;
      final urgency = entry.value.toDouble() * daysSinceCommit;
      if (urgency > highestUrgency) {
        highestUrgency = urgency;
        urgentProjectPath = entry.key;
      }
    }

    final urgentProject = urgentProjectPath != null
        ? _projects.where((p) => p.path == urgentProjectPath).firstOrNull
        : null;
    final urgentCount = urgentProjectPath != null
        ? _unreleasedCommits[urgentProjectPath] ?? 0
        : 0;

    final isUrgent = projectsWithUnreleased.length >= 3 || highestUrgency > 30;
    final bannerColor = isUrgent
        ? AppColors.warning.withValues(alpha: 0.12)
        : AppColors.accent.withValues(alpha: 0.08);
    final borderColor = isUrgent
        ? AppColors.warning.withValues(alpha: 0.3)
        : AppColors.accent.withValues(alpha: 0.2);
    final iconColor = isUrgent ? AppColors.warning : AppColors.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() => _sortMode = SortMode.lastChanged);
          SharedPreferences.getInstance().then(
            (prefs) => prefs.setInt('sortMode', SortMode.lastChanged.index),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                isUrgent
                    ? Icons.warning_amber_rounded
                    : Icons.rocket_launch_rounded,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${projectsWithUnreleased.length} project${projectsWithUnreleased.length == 1 ? '' : 's'} ${projectsWithUnreleased.length == 1 ? 'has' : 'have'} unreleased work',
                      style: AppTypography.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (urgentProject != null)
                      Text(
                        'Most urgent: ${urgentProject.name} ($urgentCount unreleased commits)',
                        style: AppTypography.inter(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.sort_rounded, size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectList(List<Project> pinned, List<Project> recent) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Release pulse banner
        _buildReleasePulse(cs),

        // CLI install banner
        if (_showCliInstallBanner)
          CliInstallBanner(
            onInstalled: () => setState(() => _showCliInstallBanner = false),
            onDismissed: () => setState(() => _showCliInstallBanner = false),
          ),

        // Pinned section
        if (pinned.isNotEmpty) ...[
          InkWell(
            onTap: () async {
              setState(() => _pinnedCollapsed = !_pinnedCollapsed);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('pinnedCollapsed', _pinnedCollapsed);
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 4,
                right: 4,
                bottom: 8,
                top: 2,
              ),
              child: Row(
                children: [
                  Icon(
                    _pinnedCollapsed
                        ? Icons.chevron_right_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'PINNED',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${pinned.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_pinnedCollapsed) ...pinned.map((p) => _buildCard(p)),
          const SizedBox(height: 16),
        ],

        // Recent section
        if (recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'RECENT PROJECTS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...recent.map((p) => _buildCard(p)),
        ],
      ],
    );
  }

  Widget _buildGridView() {
    final projects = _sortedProjects;

    return Column(
      children: [
        // CLI install banner
        if (_showCliInstallBanner)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: CliInstallBanner(
              onInstalled: () => setState(() => _showCliInstallBanner = false),
              onDismissed: () => setState(() => _showCliInstallBanner = false),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900
                  ? 5
                  : constraints.maxWidth > 600
                  ? 4
                  : 3;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.88,
                ),
                itemCount: projects.length,
                itemBuilder: (context, index) =>
                    _buildGridCard(projects[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(Project project) {
    final stack =
        _projectStacks[project.path] ??
        const ProjectStack(primary: ProjectType.unknown);
    final health = _healthScores[project.path];
    final lastCommit = health?.details.lastCommitDate;

    // Relative time
    String relTime = '';
    Color activityColor = const Color(0xFF6B7280);
    if (lastCommit != null) {
      final diff = DateTime.now().difference(lastCommit);
      if (diff.inMinutes < 60) {
        relTime = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        relTime = '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        relTime = '${diff.inDays}d ago';
      } else if (diff.inDays < 30) {
        relTime = '${(diff.inDays / 7).floor()}w ago';
      } else if (diff.inDays < 365) {
        relTime = '${(diff.inDays / 30).floor()}mo ago';
      } else {
        relTime = '${(diff.inDays / 365).floor()}y ago';
      }

      final days = diff.inDays;
      if (days <= 1) {
        activityColor = AppColors.success;
      } else if (days <= 7) {
        activityColor = AppColors.accent;
      } else if (days <= 30) {
        activityColor = AppColors.warning;
      }
    }

    // Activity badge
    String? activityBadge;
    Color? badgeColor;
    if (lastCommit != null) {
      final days = DateTime.now().difference(lastCommit).inDays;
      if (days <= 1) {
        activityBadge = 'TODAY';
        badgeColor = AppColors.success;
      } else if (days <= 7) {
        activityBadge = 'THIS WEEK';
        badgeColor = AppColors.accent;
      } else if (days <= 30) {
        activityBadge = 'THIS MONTH';
        badgeColor = AppColors.warning;
      }
    }
    if (project.isPinned && activityBadge == null) {
      activityBadge = 'PINNED';
      badgeColor = AppColors.accent;
    }

    final gridHs = _healthScores[project.path];
    return GridProjectCard(
      project: project,
      stack: stack,
      dateLabel: relTime,
      activityBadge: activityBadge,
      badgeColor: badgeColor,
      activityColor: activityColor,
      branchName: _branchNames[project.path],
      healthScore: gridHs?.details.totalScore,
      hasUncommitted: gridHs != null && !gridHs.details.noUncommittedChanges,
      hasUnpushed: _hasUnpushed(project.path),
      onTap: () => _openProjectSettings(project),
      onOpenTerminal: () => _openInTerminal(project),
      onOpenVSCode: () => _openInVSCode(project),
    );
  }

  Widget _buildCard(Project project) {
    final hs = _healthScores[project.path];
    return ProjectCard(
      project: project,
      healthScore: hs,
      projectStack:
          _projectStacks[project.path] ??
          const ProjectStack(primary: ProjectType.unknown),
      isGitRepo: _isGitRepo(project.path),
      hasUnpushed: _hasUnpushed(project.path),
      hasUncommitted: hs != null && !hs.details.noUncommittedChanges,
      branchName: _branchNames[project.path],
      hasAIInsights: _projectAIInsights[project.path] ?? false,
      version: _projectVersions[project.path],
      onRemove: () => _removeProject(project),
      onOpenTerminal: () => _openInTerminal(project),
      onOpenVSCode: () => _openInVSCode(project),
      onTogglePin: () => _togglePin(project),
      onEditTags: () => _editTags(project),
      onEditNotes: () => _editNotes(project),
      onSettings: () => _openProjectSettings(project),
    );
  }

  Widget _buildUpgradeBanner(ColorScheme cs) {
    return GestureDetector(
      onTap: _showSubscription,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.08),
              const Color(0xFFE879F9).withValues(alpha: 0.06),
            ],
          ),
          border: Border(
            top: BorderSide(color: AppColors.accent.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium,
              size: 16,
              color: Color(0xFFFFD700),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Upgrade to Pro for Year in Review, premium themes, and more',
                style: AppTypography.inter(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'View Plans',
                style: AppTypography.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    final cs = Theme.of(context).colorScheme;

    // Build a contextual message based on active filters
    final activeFilters = <String>[];
    if (_searchQuery.isNotEmpty) activeFilters.add('"$_searchQuery"');
    if (_selectedTag != null) activeFilters.add('tag: $_selectedTag');
    if (_healthFilter != HealthFilter.all)
      activeFilters.add(_healthFilter.name);
    if (_stalenessFilter != StalenessFilter.all)
      activeFilters.add('stale only');
    if (_selectedProjectType != null)
      activeFilters.add(_selectedProjectType!.label);
    if (_activityFilter != ActivityFilter.all)
      activeFilters.add(_activityFilter.name);
    if (_gitFilter != GitFilter.all) activeFilters.add(_gitFilter.name);

    final hasFilters = activeFilters.isNotEmpty;
    final title = hasFilters
        ? 'No projects match your filters'
        : 'No projects found';
    final subtitle = hasFilters
        ? 'Active filters: ${activeFilters.join(' · ')}'
        : 'Try scanning for projects or adding one manually.';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters
                ? Icons.filter_alt_off_rounded
                : Icons.search_off_rounded,
            size: 48,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => setState(() {
                _searchQuery = '';
                _searchController.clear();
                _selectedTag = null;
                _healthFilter = HealthFilter.all;
                _stalenessFilter = StalenessFilter.all;
                _selectedProjectType = null;
                _activityFilter = ActivityFilter.all;
                _gitFilter = GitFilter.all;
              }),
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear all filters'),
            ),
          ],
        ],
      ),
    );
  }
}
