import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../models/project.dart';
import '../models/health_score.dart';
import '../services/project_storage.dart';
import '../services/launcher_service.dart';
import '../services/project_scanner.dart';
import '../services/health_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home/project_card.dart';
import '../widgets/home/filter_bar.dart';
import '../widgets/home/side_panel.dart';
import '../widgets/home/status_bar.dart';
import '../widgets/theme_switcher.dart';
import '../kit/kit.dart';
import 'year_review_screen.dart';
import 'health_screen.dart';
import 'referral_screen.dart';
import 'pro_screen.dart';

enum SortMode { lastOpened, name }
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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadProjects();
    _loadHealthScores();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadProjects();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --- Data loading ---

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final sortIndex = prefs.getInt('sortMode') ?? 0;
    final viewIndex = prefs.getInt('viewMode') ?? 0;
    if (mounted) {
      setState(() {
        _sortMode = SortMode.values[sortIndex];
        _viewMode = ViewMode.values[viewIndex];
      });
    }
  }

  Future<void> _loadProjects() async {
    final projects = await ProjectStorage.loadProjects();
    final tags = await ProjectStorage.getAllTags();
    if (mounted) {
      setState(() {
        _projects = projects;
        _allTags = tags;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHealthScores() async {
    final projects = await ProjectStorage.loadProjects();
    final scores = await HealthService.getHealthScores(
      projects.map((p) => p.path).toList(),
    );
    if (mounted) {
      setState(() => _healthScores = scores);
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

    return filtered;
  }

  List<Project> get _sortedProjects {
    final sorted = List<Project>.from(_filteredProjects);

    if (_sortMode == SortMode.name) {
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      sorted.sort((a, b) {
        final aTime = a.lastOpenedAt ?? a.addedAt;
        final bTime = b.lastOpenedAt ?? b.addedAt;
        return bTime.compareTo(aTime);
      });
    }

    sorted.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });

    return sorted;
  }

  Map<String, List<Project>> get _groupedProjects {
    final groups = <String, List<Project>>{};
    for (final project in _sortedProjects) {
      final parentPath = project.path.substring(0, project.path.lastIndexOf('/'));
      final parentName = parentPath.split('/').last;
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
    final controller = TextEditingController(text: project.tags.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tags for ${project.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UkTextField(
                controller: controller,
                label: 'Tags (comma separated)',
                hint: 'work, flutter, personal',
                prefixIcon: Icons.label_rounded,
              ),
              if (_allTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Existing tags:', style: Theme.of(context).textTheme.labelMedium),
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
                    child: UkBadge(tag, variant: UkBadgeVariant.neutral),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          UkButton(
            label: 'Cancel',
            variant: UkButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UkButton(
            label: 'Save',
            variant: UkButtonVariant.primary,
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
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
    final controller = TextEditingController(text: project.notes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notes for ${project.name}'),
        content: SizedBox(
          width: 500,
          height: 200,
          child: UkTextArea(
            controller: controller,
            label: 'Notes',
            hint: 'Add notes, TODOs, or reminders...',
            minLines: 5,
            maxLines: 10,
          ),
        ),
        actions: [
          UkButton(
            label: 'Cancel',
            variant: UkButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (project.notes != null && project.notes!.isNotEmpty)
            UkButton(
              label: 'Clear',
              variant: UkButtonVariant.outline,
              icon: Icons.delete_outline,
              onPressed: () => Navigator.of(context).pop(''),
            ),
          UkButton(
            label: 'Save',
            variant: UkButtonVariant.primary,
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
      ),
    );

    if (result != null) {
      await ProjectStorage.updateNotes(project.path, result.isEmpty ? null : result);
      _loadProjects();
    }
  }

  Future<void> _addProjectManually() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Project'),
        content: SizedBox(
          width: 400,
          child: UkTextField(
            controller: controller,
            label: 'Project Path',
            hint: '/path/to/your/project',
            prefixIcon: Icons.folder_rounded,
          ),
        ),
        actions: [
          UkButton(
            label: 'Cancel',
            variant: UkButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UkButton(
            label: 'Add',
            variant: UkButtonVariant.primary,
            icon: Icons.add,
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final dir = Directory(result);
      if (await dir.exists()) {
        final name = result.split('/').last;
        final project = Project(
          name: name,
          path: result,
          addedAt: DateTime.now(),
        );
        await ProjectStorage.addProject(project);
        _loadProjects();
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          UkButton(
            label: 'Maybe Later',
            variant: UkButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UkButton(
            label: 'View Pro',
            variant: UkButtonVariant.primary,
            icon: Icons.workspace_premium,
            onPressed: () {
              Navigator.of(context).pop();
              _showProScreen();
            },
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
            // Refresh premium status in parent
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

  void _showReferrals() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReferralScreen()),
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
    final recentProjects = _sortedProjects.where((p) => !p.isPinned).toList();

    return Scaffold(
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
                sortLabel: _sortMode == SortMode.lastOpened ? 'Recent' : 'A-Z',
                onSortToggle: () {
                  final newMode = _sortMode == SortMode.lastOpened ? SortMode.name : SortMode.lastOpened;
                  setState(() => _sortMode = newMode);
                  _saveSortPreference(newMode);
                },
                onHealthFilterChanged: (f) => setState(() => _healthFilter = f),
                onStalenessFilterChanged: (f) => setState(() => _stalenessFilter = f),
                viewModeIndex: _viewMode == ViewMode.list ? 0 : 1,
                onViewModeChanged: (i) {
                  final newMode = i == 0 ? ViewMode.list : ViewMode.folder;
                  setState(() => _viewMode = newMode);
                  _saveViewPreference(newMode);
                },
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
                              ? _buildEmptyState()
                              : _sortedProjects.isEmpty
                                  ? _buildNoResults()
                                  : _buildProjectList(pinnedProjects, recentProjects),
                    ),

                    // Right side panel
                    if (_projects.isNotEmpty)
                      HomeSidePanel(
                        totalProjects: _projects.length,
                        healthyCount: _healthyCount,
                        needsAttentionCount: _needsAttentionCount,
                        isPro: false,
                        onYearReviewTap: _showYearInReview,
                        onHealthTap: _showHealthDashboard,
                      ),
                  ],
                ),
              ),

              // Status bar
              StatusBar(lastScanTime: _lastScanTime),
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
                      currentTheme: AppTheme.dark, // Will be wired to app state
                      unlockedThemes: [],
                      isPro: false,
                      onThemeChanged: (theme) {
                        // Will be wired to app state
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
    );
  }

  Widget _buildTopBar(ColorScheme cs) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          // macOS traffic light dots
          Row(
            children: [
              _TrafficLight(color: const Color(0xFFFF5F56)),
              const SizedBox(width: 8),
              _TrafficLight(color: const Color(0xFFFFBD2E)),
              const SizedBox(width: 8),
              _TrafficLight(color: const Color(0xFF27C93F)),
            ],
          ),
          const SizedBox(width: 24),

          // App title
          Text(
            'Project Launcher',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
            ),
          ),

          const SizedBox(width: 24),

          // Search bar
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: AppTypography.mono(fontSize: 13, color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search projects (Cmd+K)',
                        hintStyle: AppTypography.mono(fontSize: 13, color: cs.onSurfaceVariant),
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
                      color: cs.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '\u2318K',
                      style: AppTypography.mono(fontSize: 10, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Action icons
          IconButton(
            icon: const Icon(Icons.radar_rounded, size: 20),
            onPressed: _scanForProjects,
            tooltip: 'Scan for projects',
            color: cs.onSurfaceVariant,
          ),
          IconButton(
            icon: const Icon(Icons.terminal_rounded, size: 20),
            onPressed: () {},
            tooltip: 'Terminal',
            color: cs.onSurfaceVariant,
          ),
          IconButton(
            icon: const Icon(Icons.code_rounded, size: 20),
            onPressed: () {},
            tooltip: 'VS Code',
            color: cs.onSurfaceVariant,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 20),
            onPressed: _addProjectManually,
            tooltip: 'Add project',
            color: cs.onSurfaceVariant,
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 20),
            onPressed: () => setState(() => _showThemeSwitcher = !_showThemeSwitcher),
            tooltip: 'Settings',
            color: cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList(List<Project> pinned, List<Project> recent) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pinned section
        if (pinned.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'PINNED',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...pinned.map((p) => _buildCard(p)),
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

  Widget _buildCard(Project project) {
    return ProjectCard(
      project: project,
      healthScore: _healthScores[project.path],
      onRemove: () => _removeProject(project),
      onOpenTerminal: () => _openInTerminal(project),
      onOpenVSCode: () => _openInVSCode(project),
      onTogglePin: () => _togglePin(project),
      onEditTags: () => _editTags(project),
      onEditNotes: () => _editNotes(project),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.terminal_rounded, size: 64, color: AppColors.accent.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text(
            'Welcome to your command center',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Project Launcher organizes your local repositories and gives you\ninstant access to your code.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _scanForProjects,
                icon: const Icon(Icons.search),
                label: const Text('Auto-Scan Machine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _addProjectManually,
                icon: const Icon(Icons.add),
                label: const Text('Add Manually'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF69B4),
                  side: const BorderSide(color: Color(0xFFFF69B4)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'No results for "$_searchQuery"',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficLight extends StatelessWidget {
  final Color color;
  const _TrafficLight({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
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

    final result = await ProjectScanner.scanCustomPath(path);

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
    final home = Platform.environment['HOME'] ?? '';

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
        // Add custom folder button
        OutlinedButton.icon(
          onPressed: _browseFolder,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Custom Folder...'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.onSurfaceVariant,
            side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            minimumSize: const Size(double.infinity, 42),
          ),
        ),
        const SizedBox(height: 20),
        // Scan depth
        Row(
          children: [
            Text('Scan Depth', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface)),
            const Spacer(),
            Text('2 Levels', style: AppTypography.mono(fontSize: 13, color: AppColors.accent)),
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
    final home = Platform.environment['HOME'] ?? '';
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
