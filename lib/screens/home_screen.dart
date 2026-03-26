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
import '../widgets/home/cli_install_banner.dart';

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
      final filePath = '${PlatformHelper.dataDir}${Platform.pathSeparator}projects.json';
      final file = File(filePath);
      if (!file.existsSync()) {
        // File doesn't exist yet — watch the directory instead
        final dir = Directory(PlatformHelper.dataDir);
        if (!dir.existsSync()) return;
        _projectsFileWatcher = dir.watch(events: FileSystemEvent.create | FileSystemEvent.modify).listen((event) {
          if (event.path.endsWith('projects.json')) {
            AppLogger.info('FileWatch', 'projects.json changed (directory event), reloading');
            _loadProjects();
            _loadHealthScores();
            _loadAIInsightsFlags();
          }
        });
        AppLogger.info('FileWatch', 'Watching directory for projects.json creation');
        return;
      }
      _projectsFileWatcher = file.watch(events: FileSystemEvent.modify).listen((event) {
        AppLogger.info('FileWatch', 'projects.json modified externally, reloading');
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
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains(query) ||
        p.path.toLowerCase().contains(query) ||
        p.tags.any((t) => t.toLowerCase().contains(query)) ||
        (p.notes?.toLowerCase().contains(query) ?? false)
      ).toList();
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
        final startOfThisWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
        final startOfThisMonth = DateTime(now.year, now.month, 1);
        final startOfLastMonth = DateTime(now.year, now.month - 1, 1);

        switch (_activityFilter) {
          case ActivityFilter.thisWeek:
            return lastCommit.isAfter(startOfThisWeek);
          case ActivityFilter.lastWeek:
            return lastCommit.isAfter(startOfLastWeek) && lastCommit.isBefore(startOfThisWeek);
          case ActivityFilter.thisMonth:
            return lastCommit.isAfter(startOfThisMonth);
          case ActivityFilter.lastMonth:
            return lastCommit.isAfter(startOfLastMonth) && lastCommit.isBefore(startOfThisMonth);
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
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
    final sortedKeys = groups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (var k in sortedKeys) k: groups[k]!};
  }

  // --- Health counts ---

  int get _healthyCount => _healthScores.values
      .where((s) => s.details.category == HealthCategory.healthy).length;

  int get _needsAttentionCount => _healthScores.values
      .where((s) => s.details.category == HealthCategory.needsAttention).length;

  Map<ActivityFilter, int> get _activityCounts {
    final counts = <ActivityFilter, int>{};
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfThisWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
                style: AppTypography.mono(fontSize: 13, color: cs.onSurface),
              ),
              if (_allTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Existing tags:', style: Theme.of(ctx).textTheme.labelMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _allTags.map((tag) => InkWell(
                    onTap: () {
                      final current = controller.text;
                      if (current.isEmpty) {
                        controller.text = tag;
                      } else if (!current.split(',').map((t) => t.trim()).contains(tag)) {
                        controller.text = '$current, $tag';
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(tag, style: Theme.of(ctx).textTheme.labelSmall),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );

    if (result != null) {
      final tags = result.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
            style: AppTypography.mono(fontSize: 13, color: cs.onSurface),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          if (project.notes != null && project.notes!.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: Text('Clear', style: TextStyle(color: AppColors.error)),
            ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );

    if (result != null) {
      await ProjectStorage.updateNotes(project.path, result.isEmpty ? null : result);
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
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const YearReviewScreen()),
      );
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Maybe Later')),
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HealthScreen()),
    );
  }

  void _showInsights() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InsightsScreen()),
    );
  }

  void _showReferrals() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReferralScreen()),
    );
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
                  color: cs.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text('Server Status',
                      style: Theme.of(ctx).textTheme.titleSmall),
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
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Base URL',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      SelectableText(
                        'http://localhost:${ApiServer.port}/api',
                        style: AppTypography.mono(fontSize: 12, color: AppColors.accent),
                      ),
                      const SizedBox(height: 12),
                      Text('Try it:',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      SelectableText(
                        'curl localhost:${ApiServer.port}/api/projects',
                        style: AppTypography.mono(fontSize: 11, color: cs.onSurface),
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
      builder: (ctx) => _ExportDialog(projects: _projects),
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
      builder: (context) => const _ScanDialog(),
    );

    if (result != null && result.newlyAdded > 0) {
      _loadProjects();
      _loadHealthScores();
      setState(() => _lastScanTime = DateTime.now());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${result.newlyAdded} new project${result.newlyAdded == 1 ? '' : 's'}'),
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
                onHealthFilterChanged: (f) => setState(() => _healthFilter = f),
                onStalenessFilterChanged: (f) => setState(() => _stalenessFilter = f),
                viewModeIndex: _viewMode == ViewMode.list ? 0 : 1,
                onViewModeChanged: (i) {
                  final newMode = i == 0 ? ViewMode.list : ViewMode.folder;
                  setState(() => _viewMode = newMode);
                  _saveViewPreference(newMode);
                },
                allTags: _allTags,
                selectedTag: _selectedTag,
                onTagChanged: (tag) => setState(() => _selectedTag = tag),
                availableProjectTypes: _projectStacks.values.expand((s) => s.all).where((t) => t != ProjectType.unknown).toSet(),
                selectedProjectType: _selectedProjectType,
                onProjectTypeChanged: (type) => setState(() => _selectedProjectType = type),
                activityFilter: _activityFilter,
                onActivityFilterChanged: (f) => setState(() => _activityFilter = f),
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
                          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                          : _projects.isEmpty
                              ? OnboardingScreen(
                                  onStartScan: _scanForProjects,
                                  onAddManually: _addProjectManually,
                                )
                              : _sortedProjects.isEmpty
                                  ? _buildNoResults()
                                  : _viewMode == ViewMode.folder
                                      ? _buildGridView()
                                      : _buildProjectList(pinnedProjects, recentProjects),
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
              if (!_isPro && _projects.isNotEmpty)
                _buildUpgradeBanner(cs),

              // Status bar
              StatusBar(
                lastScanTime: _lastScanTime,
                unreleasedCount: _unreleasedCommits.values.where((c) => c > 0).length,
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
                      unlockedThemes: appState?.unlockedThemes ?? [],
                      isPro: _isPro,
                      onThemeChanged: (theme) {
                        appState?.setTheme(theme);
                        setState(() => _showThemeSwitcher = false);
                      },
                      onClose: () => setState(() => _showThemeSwitcher = false),
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
                Icon(Icons.rocket_launch_rounded, size: 16, color: AppColors.accent),
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
                  Icon(Icons.search_rounded, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: AppTypography.inter(fontSize: 13, color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search projects...',
                        hintStyle: AppTypography.inter(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '\u2318K',
                      style: AppTypography.mono(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Syncing indicator
          if (BackgroundMonitor.status == MonitorStatus.checking)
            _SyncingPill(
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
          _HeaderButton(
            icon: Icons.radar_rounded,
            tooltip: 'Scan for projects',
            onPressed: _scanForProjects,
          ),
          _HeaderButton(
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
            _HeaderButton(
              icon: Icons.workspace_premium_rounded,
              tooltip: 'Upgrade to Pro',
              onPressed: _showSubscription,
              accentColor: const Color(0xFFFFD700),
            ),

          // Plugins
          _HeaderButton(
            icon: Icons.extension_rounded,
            tooltip: 'Plugins',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PluginsScreen()),
            ),
          ),

          // API Server
          _HeaderButton(
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
              _HeaderButton(
                icon: NotificationService.isRunning
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                ).then((_) => setState(() {})),
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
          _HeaderButton(
            icon: Icons.dashboard_customize_rounded,
            tooltip: 'Customize Dashboard',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DashboardCustomizeScreen(
                  onSaved: () => setState(() {}),
                ),
              ),
            ),
          ),

          // Export all projects as zip
          _HeaderButton(
            icon: Icons.archive_rounded,
            tooltip: 'Export projects as ZIP',
            onPressed: _showExportDialog,
          ),

          // CLI Install
          _HeaderButton(
            icon: Icons.terminal_rounded,
            tooltip: _showCliInstallBanner ? 'Install plauncher CLI' : 'plauncher CLI',
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
          _HeaderButton(
            icon: Icons.palette_outlined,
            tooltip: 'Theme',
            onPressed: () => setState(() => _showThemeSwitcher = !_showThemeSwitcher),
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
              const Icon(Icons.workspace_premium, size: 12, color: Colors.black87),
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
          SharedPreferences.getInstance().then((prefs) =>
              prefs.setInt('sortMode', SortMode.lastChanged.index));
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
                isUrgent ? Icons.warning_amber_rounded : Icons.rocket_launch_rounded,
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
              Icon(
                Icons.sort_rounded,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
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
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8, top: 2),
              child: Row(
                children: [
                  Icon(
                    _pinnedCollapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
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
              final crossAxisCount = constraints.maxWidth > 900 ? 5 : constraints.maxWidth > 600 ? 4 : 3;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.88,
                ),
                itemCount: projects.length,
                itemBuilder: (context, index) => _buildGridCard(projects[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(Project project) {
    final stack = _projectStacks[project.path] ?? const ProjectStack(primary: ProjectType.unknown);
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
    return _GridProjectCard(
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
      projectStack: _projectStacks[project.path] ?? const ProjectStack(primary: ProjectType.unknown),
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
          border: Border(top: BorderSide(color: AppColors.accent.withValues(alpha: 0.15))),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, size: 16, color: Color(0xFFFFD700)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Upgrade to Pro for Year in Review, premium themes, and more',
                style: AppTypography.inter(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'View Plans',
                style: AppTypography.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
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
    if (_healthFilter != HealthFilter.all) activeFilters.add(_healthFilter.name);
    if (_stalenessFilter != StalenessFilter.all) activeFilters.add('stale only');
    if (_selectedProjectType != null) activeFilters.add(_selectedProjectType!.label);
    if (_activityFilter != ActivityFilter.all) activeFilters.add(_activityFilter.name);
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
            hasFilters ? Icons.filter_alt_off_rounded : Icons.search_off_rounded,
            size: 48,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
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

class _GridProjectCard extends StatefulWidget {
  final Project project;
  final ProjectStack stack;
  final String dateLabel;
  final String? activityBadge;
  final Color? badgeColor;
  final Color activityColor;
  final String? branchName;
  final int? healthScore;
  final bool hasUncommitted;
  final bool hasUnpushed;
  final VoidCallback onTap;
  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenVSCode;

  const _GridProjectCard({
    required this.project,
    required this.stack,
    required this.dateLabel,
    this.activityBadge,
    this.badgeColor,
    this.activityColor = const Color(0xFF6B7280),
    this.branchName,
    this.healthScore,
    this.hasUncommitted = false,
    this.hasUnpushed = false,
    required this.onTap,
    required this.onOpenTerminal,
    required this.onOpenVSCode,
  });

  @override
  State<_GridProjectCard> createState() => _GridProjectCardState();
}

class _GridProjectCardState extends State<_GridProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = widget.stack.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isHovered ? cs.surfaceContainerHighest : cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? cs.outline.withValues(alpha: 0.4)
                  : cs.outline.withValues(alpha: 0.12),
            ),
            boxShadow: _isHovered
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Large icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: primary.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: Icon(primary.icon, size: 28, color: primary.color),
                          ),
                          // Secondary badge
                          if (widget.stack.secondary.isNotEmpty)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: widget.stack.secondary.first.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cs.surface, width: 2),
                                ),
                                child: Icon(
                                  widget.stack.secondary.first.icon,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Project name
                    Text(
                      widget.project.name,
                      style: AppTypography.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    // Date + micro indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.dateLabel.isNotEmpty ? widget.dateLabel : 'No commits',
                          style: AppTypography.mono(
                            fontSize: 11,
                            color: widget.dateLabel.isNotEmpty
                                ? widget.activityColor.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        if (widget.healthScore != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: widget.healthScore! >= 80
                                  ? AppColors.success
                                  : widget.healthScore! >= 50
                                      ? AppColors.warning
                                      : AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        if (widget.hasUncommitted)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.edit_note_rounded, size: 12, color: AppColors.warning.withValues(alpha: 0.8)),
                          ),
                        if (widget.hasUnpushed)
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Icon(Icons.cloud_upload_outlined, size: 11, color: AppColors.warning.withValues(alpha: 0.8)),
                          ),
                      ],
                    ),
                    // Branch name
                    if (widget.branchName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fork_right_rounded, size: 10, color: AppColors.accent.withValues(alpha: 0.6)),
                          const SizedBox(width: 2),
                          Text(
                            widget.branchName!,
                            style: AppTypography.mono(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                    // Tags
                    if (widget.project.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 3,
                        runSpacing: 2,
                        children: widget.project.tags.take(2).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                          ),
                        )).toList(),
                      ),
                    ],
                    // Tech stack pills (show on hover)
                    if (_isHovered && widget.stack.all.length > 1) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 3,
                        children: widget.stack.all.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: t.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.label,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: t.color),
                          ),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Activity badge (top center)
              if (widget.activityBadge != null)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.badgeColor?.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: widget.badgeColor?.withValues(alpha: 0.4) ?? Colors.transparent),
                      ),
                      child: Text(
                        widget.activityBadge!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: widget.badgeColor,
                        ),
                      ),
                    ),
                  ),
                ),

              // Pin indicator
              if (widget.project.isPinned && widget.activityBadge != 'PINNED')
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                ),

              // Hover actions (bottom)
              if (_isHovered)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GridAction(icon: Icons.terminal_rounded, tooltip: 'Terminal', onTap: widget.onOpenTerminal),
                      const SizedBox(width: 4),
                      _GridAction(icon: Icons.code_rounded, tooltip: 'VS Code', onTap: widget.onOpenVSCode),
                      const SizedBox(width: 4),
                      _GridAction(
                        icon: Icons.folder_open_rounded,
                        tooltip: 'Finder',
                        onTap: () => LauncherService.openInFinder(widget.project.path),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _GridAction({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 14, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _SyncingPill extends StatefulWidget {
  final int progress;
  final int total;

  const _SyncingPill({required this.progress, required this.total});

  @override
  State<_SyncingPill> createState() => _SyncingPillState();
}

class _SyncingPillState extends State<_SyncingPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = widget.total > 0
        ? 'Syncing ${widget.progress}/${widget.total}'
        : 'Syncing...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _controller,
            child: const Icon(Icons.sync_rounded, size: 13, color: AppColors.accent),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? accentColor;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accentColor,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.accentColor ?? cs.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.accentColor ?? cs.onSurface).withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _hovered ? (widget.accentColor ?? cs.onSurface) : color.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Scan Dialog (kept inline for now) ---

class _ScanDialog extends StatefulWidget {
  const _ScanDialog();

  @override
  State<_ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends State<_ScanDialog> {
  bool _isScanning = false;
  bool _isDone = false;
  String _currentPath = '';
  int _foundCount = 0;
  int _dirCount = 0;
  ScanResult? _result;
  final _customPathController = TextEditingController();
  final Stopwatch _stopwatch = Stopwatch();
  int _scanDepth = 3;
  bool _infiniteDepth = false;

  @override
  void dispose() {
    _customPathController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _currentPath = 'Starting scan...';
      _foundCount = 0;
      _dirCount = 0;
    });
    _stopwatch.start();

    final result = await ProjectScanner.scanAndAddProjects(
      maxDepth: _infiniteDepth ? null : _scanDepth,
      onProgress: (path) {
        if (mounted) {
          setState(() {
            _currentPath = path;
            _dirCount++;
          });
        }
      },
      onFound: (count) {
        if (mounted) {
          setState(() => _foundCount = count);
        }
      },
    );

    _stopwatch.stop();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _isDone = true;
        _result = result;
      });
    }
  }

  Future<void> _browseFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder to scan',
    );
    if (result != null) {
      _customPathController.text = result;
    }
  }

  Future<void> _scanCustomPath() async {
    final path = _customPathController.text.trim();
    if (path.isEmpty) return;

    setState(() {
      _isScanning = true;
      _currentPath = path;
    });

    final result = await ProjectScanner.scanCustomPath(path, maxDepth: _infiniteDepth ? null : _scanDepth);

    if (mounted) {
      setState(() {
        _isScanning = false;
        _isDone = true;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scan for Projects', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Automatically discover git repositories on your machine',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(_result),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_isDone)
              _buildResultView(cs)
            else if (_isScanning)
              _buildScanningView(cs)
            else
              _buildStartView(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildStartView(ColorScheme cs) {
    final scanPaths = ProjectScanner.getScanPaths();
    final home = PlatformHelper.homeDir;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT DIRECTORIES', style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          letterSpacing: 1.2,
        )),
        const SizedBox(height: 12),
        ...scanPaths.take(4).map((path) {
          final exists = Directory(path).existsSync();
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: exists ? AppColors.accent.withValues(alpha: 0.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: exists ? AppColors.accent.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  exists ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: exists ? AppColors.accent : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path.replaceFirst(home, '~'),
                        style: AppTypography.mono(fontSize: 13, color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        // Add custom folder
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customPathController,
                decoration: InputDecoration(
                  hintText: 'Custom folder path...',
                  hintStyle: AppTypography.mono(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  prefixIcon: Icon(Icons.folder_open, size: 16, color: cs.onSurfaceVariant),
                  filled: true,
                  fillColor: cs.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                ),
                style: AppTypography.mono(fontSize: 12, color: cs.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _browseFolder,
              icon: const Icon(Icons.folder_open, size: 18),
              tooltip: 'Browse',
              style: IconButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _scanCustomPath,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
              ),
              child: const Text('Scan'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Scan depth
        Row(
          children: [
            Text('Scan Depth', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface)),
            const Spacer(),
            if (!_infiniteDepth) ...[
              IconButton(
                onPressed: _scanDepth > 1 ? () => setState(() => _scanDepth--) : null,
                icon: const Icon(Icons.remove, size: 16),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  maximumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  foregroundColor: cs.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_scanDepth',
                  style: AppTypography.mono(fontSize: 14, color: AppColors.accent),
                ),
              ),
              IconButton(
                onPressed: _scanDepth < 20 ? () => setState(() => _scanDepth++) : null,
                icon: const Icon(Icons.add, size: 16),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  maximumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  foregroundColor: cs.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('∞', style: AppTypography.mono(fontSize: 18, color: AppColors.accent)),
              ),
            GestureDetector(
              onTap: () => setState(() => _infiniteDepth = !_infiniteDepth),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _infiniteDepth ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _infiniteDepth ? AppColors.accent : cs.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Infinite',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _infiniteDepth ? AppColors.accent : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Start scan button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
            child: const Text('Start Scan'),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningView(ColorScheme cs) {
    final home = PlatformHelper.homeDir;
    final elapsed = _stopwatch.elapsed;
    final elapsedStr = '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}s';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 20),
        Text('Scanning Filesystem...', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            _currentPath.replaceFirst(home, '~'),
            style: AppTypography.mono(fontSize: 11, color: AppColors.accent),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ScanStat(label: 'DIRECTORIES', value: _dirCount.toString()),
            _ScanStat(label: 'REPOS FOUND', value: _foundCount.toString()),
            _ScanStat(label: 'ELAPSED', value: elapsedStr),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResultView(ColorScheme cs) {
    final result = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.accent),
        ),
        const SizedBox(height: 20),
        Text('Scan Complete', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ScanStat(label: 'Found', value: result.totalFound.toString()),
            _ScanStat(label: 'Added', value: result.newlyAdded.toString()),
            _ScanStat(label: 'Existing', value: result.alreadyExists.toString()),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_result),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

class _ScanStat extends StatelessWidget {
  final String label;
  final String value;
  const _ScanStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          letterSpacing: 1,
        )),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.mono(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        )),
      ],
    );
  }
}

// --- Export Dialog ---

class _ExportDialog extends StatefulWidget {
  final List<Project> projects;
  const _ExportDialog({required this.projects});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late Map<String, bool> _selected;
  bool _includeGitDir = false;
  bool _isExporting = false;
  bool _isDone = false;
  int _currentProject = 0;
  int _totalProjects = 0;
  String _currentName = '';
  ExportResult? _result;
  String? _error;

  // Push to Git state
  bool _showPushForm = false;
  bool _isPushing = false;
  bool _pushDone = false;
  String _pushStatus = '';
  BatchPushResult? _pushResult;
  String? _pushError;
  final List<PushLogEntry> _pushLogs = [];
  final _pushLogScrollController = ScrollController();
  final _remoteUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _obscureToken = true;
  final _commitMsgController =
      TextEditingController(text: 'Initial commit — fresh export');
  final _exportSearchController = TextEditingController();
  String _exportSearchQuery = '';
  bool _pushConfig = true;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final p in widget.projects) p.path: true,
    };
    _loadGitSettings();
  }

  Future<void> _loadGitSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('git_push_url') ?? '';
    final token = prefs.getString('git_push_token') ?? '';
    if (url.isNotEmpty) _remoteUrlController.text = url;
    if (token.isNotEmpty) _tokenController.text = token;
  }

  Future<void> _saveGitSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('git_push_url', _remoteUrlController.text.trim());
    await prefs.setString('git_push_token', _tokenController.text.trim());
  }

  @override
  void dispose() {
    _remoteUrlController.dispose();
    _tokenController.dispose();
    _commitMsgController.dispose();
    _exportSearchController.dispose();
    _pushLogScrollController.dispose();
    super.dispose();
  }

  int get _selectedCount => _selected.values.where((v) => v).length;

  List<Project> get _selectedProjects =>
      widget.projects.where((p) => _selected[p.path] == true).toList();

  Future<void> _startExport() async {
    final projects = _selectedProjects;
    if (projects.isEmpty) return;

    setState(() {
      _isExporting = true;
      _totalProjects = projects.length;
      _currentProject = 0;
      _error = null;
    });

    try {
      final result = await ExportService.exportProjects(
        projects: projects,
        includeGitDir: _includeGitDir,
        onProgress: (current, total, name) {
          if (mounted) {
            setState(() {
              _currentProject = current;
              _totalProjects = total;
              _currentName = name;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isDone = true;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _startPush() async {
    final remoteUrl = _remoteUrlController.text.trim();
    if (remoteUrl.isEmpty) return;

    final projects = _selectedProjects;
    if (projects.isEmpty) return;

    // Persist git settings for next time
    await _saveGitSettings();

    setState(() {
      _isPushing = true;
      _pushError = null;
      _pushStatus = 'Preparing...';
      _pushLogs.clear();
    });

    try {
      final result = await FreshPushService.pushProjects(
        projects: projects,
        remoteUrlTemplate: remoteUrl,
        token: _tokenController.text.trim().isNotEmpty
            ? _tokenController.text.trim()
            : null,
        commitMessage: _commitMsgController.text.trim(),
        onProgress: (current, total, name, status) {
          if (mounted) {
            setState(() {
              _currentProject = current;
              _totalProjects = total;
              _currentName = name;
              _pushStatus = status;
            });
          }
        },
        onLog: (entry) {
          if (mounted) {
            setState(() => _pushLogs.add(entry));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pushLogScrollController.hasClients) {
                _pushLogScrollController.animateTo(
                  _pushLogScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isPushing = false;
          _pushDone = true;
          _pushResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPushing = false;
          _pushError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Determine which phase we're in
    final String title;
    final Widget content;
    final List<Widget>? actions;

    if (_pushDone) {
      title = 'Push Complete';
      content = _buildPushDoneContent(cs);
      actions = [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Done'),
        ),
      ];
    } else if (_isPushing) {
      title = 'Pushing to Git...';
      content = _buildPushProgressContent(cs);
      actions = null;
    } else if (_showPushForm) {
      title = 'Push to Git';
      content = _buildPushFormContent(cs);
      actions = [
        TextButton(
          onPressed: () => setState(() => _showPushForm = false),
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed:
              _remoteUrlController.text.trim().isNotEmpty ? _startPush : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Push'),
        ),
      ];
    } else if (_isDone) {
      title = 'Export Complete';
      content = _buildDoneContent(cs);
      actions = [
        TextButton(
          onPressed: () async {
            if (_result != null) {
              await Process.run('open', ['-R', _result!.zipPath]);
            }
          },
          child: const Text('Reveal in Finder'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Done'),
        ),
      ];
    } else if (_isExporting) {
      title = 'Exporting...';
      content = _buildProgressContent(cs);
      actions = null;
    } else {
      title = 'Export Projects';
      content = _buildSelectionContent(cs);
      actions = [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: _selectedCount > 0
              ? () => setState(() => _showPushForm = true)
              : null,
          icon: const Icon(Icons.cloud_upload_rounded, size: 16),
          label: const Text('Push to Git'),
        ),
        ElevatedButton(
          onPressed: _selectedCount > 0 ? _startExport : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
          ),
          child: Text(
              'Save ZIP to Desktop'),
        ),
      ];
    }

    return AlertDialog(
      backgroundColor: cs.surface,
      title: Row(
        children: [
          Icon(
            _showPushForm || _isPushing || _pushDone
                ? Icons.cloud_upload_rounded
                : Icons.archive_rounded,
            color: AppColors.accent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(title),
        ],
      ),
      content: SizedBox(width: 480, child: content),
      actions: actions,
    );
  }

  Widget _buildSelectionContent(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select projects to include in the ZIP archive. '
          'Large directories (node_modules, build, .git, etc.) are excluded by default.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        // Select all / none
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() {
                for (final key in _selected.keys) {
                  _selected[key] = true;
                }
              }),
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('All'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => setState(() {
                for (final key in _selected.keys) {
                  _selected[key] = false;
                }
              }),
              icon: const Icon(Icons.deselect, size: 16),
              label: const Text('None'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const Spacer(),
            Text(
              '$_selectedCount of ${widget.projects.length} selected',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Search bar
        Container(
          height: 34,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _exportSearchController,
                  onChanged: (v) => setState(() => _exportSearchQuery = v),
                  style: AppTypography.inter(fontSize: 13, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search projects...',
                    hintStyle: AppTypography.inter(
                        fontSize: 13,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_exportSearchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _exportSearchController.clear();
                    _exportSearchQuery = '';
                  }),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(Icons.close_rounded, size: 16,
                        color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Project list (filtered by search)
        Builder(builder: (context) {
          final query = _exportSearchQuery.toLowerCase();
          final filtered = widget.projects
              .where((p) =>
                  query.isEmpty ||
                  p.name.toLowerCase().contains(query) ||
                  p.path.toLowerCase().contains(query))
              .toList();

          return Container(
            height: 260,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
            ),
            child: filtered.isEmpty
                ? Center(
                    child: Text('No projects match "$_exportSearchQuery"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant)),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final project = filtered[index];
                      final isSelected = _selected[project.path] ?? false;
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) =>
                            setState(() => _selected[project.path] = val ?? false),
                        title: Text(
                          project.name,
                          style: AppTypography.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          PlatformHelper.shortenPath(project.path),
                          style: AppTypography.mono(
                            fontSize: 11,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.accent,
                      );
                    },
                  ),
          );
        }),
        const SizedBox(height: 12),

        // Include .git toggle
        Row(
          children: [
            Switch(
              value: _includeGitDir,
              activeThumbColor: AppColors.accent,
              onChanged: (val) => setState(() => _includeGitDir = val),
            ),
            const SizedBox(width: 8),
            Text(
              'Include .git directories',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Tooltip(
              message: 'Including .git directories preserves full history but increases file size significantly',
              child: Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
          ],
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressContent(ColorScheme cs) {
    final progress = _totalProjects > 0 ? _currentProject / _totalProjects : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            value: progress,
            backgroundColor: cs.surfaceContainerHighest,
            color: AppColors.accent,
            strokeWidth: 4,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Zipping projects...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '$_currentProject of $_totalProjects — $_currentName',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: cs.surfaceContainerHighest,
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDoneContent(ColorScheme cs) {
    final result = _result!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Icon(Icons.check_circle_rounded, size: 56, color: AppColors.success),
        const SizedBox(height: 16),
        Text(
          '${result.projectCount} projects exported',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.folder_zip_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      PlatformHelper.shortenPath(result.zipPath),
                      style: AppTypography.mono(fontSize: 12, color: cs.onSurface),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.data_usage_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    result.fileSizeFormatted,
                    style: AppTypography.mono(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPushFormContent(ColorScheme cs) {
    final projectCount = _selectedCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Strip existing git history, create a fresh repo, and push to a remote. '
          'Files like node_modules, build, .git are excluded.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        // Remote URL input
        TextField(
          controller: _remoteUrlController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Repository URL',
            hintText: 'https://github.com/user/repo.git',
            helperText: 'Use {name} as placeholder for per-project repos',
            helperMaxLines: 2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            prefixIcon: const Icon(Icons.link, size: 18),
          ),
          style: AppTypography.mono(fontSize: 13, color: cs.onSurface),
        ),
        const SizedBox(height: 12),

        // Personal Access Token input
        TextField(
          controller: _tokenController,
          obscureText: _obscureToken,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Personal Access Token',
            hintText: 'ghp_... or github_pat_...',
            helperText: 'Required for HTTPS push authentication',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            prefixIcon: const Icon(Icons.key_rounded, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureToken ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
            ),
          ),
          style: AppTypography.mono(fontSize: 13, color: cs.onSurface),
        ),
        const SizedBox(height: 12),

        // Commit message input
        TextField(
          controller: _commitMsgController,
          decoration: InputDecoration(
            labelText: 'Commit message',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            prefixIcon: const Icon(Icons.message_outlined, size: 18),
          ),
          style: AppTypography.inter(fontSize: 13, color: cs.onSurface),
        ),
        const SizedBox(height: 12),

        // Push config toggle
        Row(
          children: [
            Switch(
              value: _pushConfig,
              activeThumbColor: AppColors.accent,
              onChanged: (val) => setState(() => _pushConfig = val),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Include project configuration (paths of all projects)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Tooltip(
              message: 'Pushes a projects.json with name and path for every project in your dashboard',
              child: Icon(Icons.info_outline, size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Mode explanation
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_remoteUrlController.text.contains('{name}')) ...[
                Row(
                  children: [
                    Icon(Icons.account_tree_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Per-project mode',
                      style: AppTypography.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Each of the $projectCount projects will be pushed to its own repo.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(Icons.folder_copy_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Combined mode',
                      style: AppTypography.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'All $projectCount projects will be pushed as folders in a single repo.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (_pushError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _pushError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPushProgressContent(ColorScheme cs) {
    final progress = _totalProjects > 0 ? _currentProject / _totalProjects : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),

        // Current status header
        Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                backgroundColor: cs.surfaceContainerHighest,
                color: AppColors.accent,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentName.isNotEmpty ? _currentName : 'Preparing...',
                    style: AppTypography.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _pushStatus,
                    style: AppTypography.inter(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_totalProjects > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$_currentProject / $_totalProjects',
                  style: AppTypography.mono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress bar
        LinearProgressIndicator(
          value: progress > 0 ? progress : null,
          backgroundColor: cs.surfaceContainerHighest,
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 12),

        // Activity log
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
          ),
          child: _pushLogs.isEmpty
              ? Center(
                  child: Text(
                    'Starting...',
                    style: AppTypography.inter(
                        fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  ),
                )
              : ListView.builder(
                  controller: _pushLogScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: _pushLogs.length,
                  itemBuilder: (context, index) {
                    final entry = _pushLogs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}',
                            style: AppTypography.mono(
                              fontSize: 10,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(entry.icon, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: entry.message,
                                    style: AppTypography.inter(
                                      fontSize: 12,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (entry.detail != null) ...[
                                    TextSpan(
                                      text: '  ${entry.detail}',
                                      style: AppTypography.inter(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPushDoneContent(ColorScheme cs) {
    final result = _pushResult!;

    // Build summary text
    final parts = <String>[];
    if (result.succeeded > 0) parts.add('${result.succeeded} pushed');
    if (result.skipped > 0) parts.add('${result.skipped} already synced');
    if (result.failed > 0) parts.add('${result.failed} failed');
    final summary = parts.join(', ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Icon(
          result.failed == 0
              ? Icons.check_circle_rounded
              : Icons.warning_rounded,
          size: 56,
          color: result.failed == 0 ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(height: 16),
        Text(summary, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        // Results list
        Container(
          constraints: const BoxConstraints(maxHeight: 250),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: result.results.length,
            itemBuilder: (context, index) {
              final r = result.results[index];

              final IconData icon;
              final Color iconColor;
              final String? subtitle;

              if (r.skipped) {
                icon = Icons.cloud_done_rounded;
                iconColor = cs.onSurfaceVariant;
                subtitle = 'Already on GitHub';
              } else if (r.success) {
                icon = Icons.check_circle_rounded;
                iconColor = AppColors.success;
                subtitle = r.parts > 1
                    ? 'Uploaded in ${r.parts} parts'
                    : null;
              } else {
                icon = Icons.error_rounded;
                iconColor = AppColors.error;
                subtitle = r.error;
              }

              return ListTile(
                dense: true,
                leading: Icon(icon, size: 18, color: iconColor),
                title: Text(
                  r.projectName,
                  style: AppTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: r.skipped
                        ? cs.onSurfaceVariant
                        : cs.onSurface,
                  ),
                ),
                subtitle: subtitle != null
                    ? Text(
                        subtitle,
                        style: AppTypography.mono(
                          fontSize: 11,
                          color: r.skipped || r.success
                              ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                              : AppColors.error.withValues(alpha: 0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
