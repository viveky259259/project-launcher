import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'models/project.dart';
import 'models/health_score.dart';
import 'services/project_storage.dart';
import 'services/launcher_service.dart';
import 'services/project_scanner.dart';
import 'services/health_service.dart';
import 'services/referral_service.dart';
import 'screens/year_review_screen.dart';
import 'screens/health_screen.dart';
import 'screens/referral_screen.dart';
import 'theme.dart';
import 'kit/kit.dart';

enum SortMode { lastOpened, name }
enum ViewMode { list, folder }
enum HealthFilter { all, healthy, needsAttention, critical }
enum StalenessFilter { all, staleOnly }

void main() {
  runApp(const ProjectLauncherApp());
}

class ProjectLauncherApp extends StatefulWidget {
  const ProjectLauncherApp({super.key});

  static _ProjectLauncherAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_ProjectLauncherAppState>();
  }

  @override
  State<ProjectLauncherApp> createState() => _ProjectLauncherAppState();
}

class _ProjectLauncherAppState extends State<ProjectLauncherApp> {
  AppTheme _currentTheme = AppTheme.dark;
  List<String> _unlockedThemes = [];

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('appTheme') ?? AppTheme.dark.index;
    final unlockedThemes = await ReferralService.getUnlockedThemes();

    if (mounted) {
      setState(() {
        _currentTheme = AppTheme.values[themeIndex];
        _unlockedThemes = unlockedThemes;

        // If current theme is locked, fall back to dark
        if (_currentTheme.requiresUnlock &&
            _currentTheme.unlockRewardId != null &&
            !_unlockedThemes.contains(_currentTheme.unlockRewardId)) {
          _currentTheme = AppTheme.dark;
        }
      });
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    // Check if theme is unlocked
    if (theme.requiresUnlock &&
        theme.unlockRewardId != null &&
        !_unlockedThemes.contains(theme.unlockRewardId)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appTheme', theme.index);

    if (mounted) {
      setState(() => _currentTheme = theme);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Launcher',
      debugShowCheckedModeBanner: false,
      theme: _currentTheme.themeData,
      home: const ProjectListScreen(),
    );
  }
}

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
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

  Future<void> _loadHealthScores() async {
    final projects = await ProjectStorage.loadProjects();
    final scores = await HealthService.getHealthScores(
      projects.map((p) => p.path).toList(),
    );
    if (mounted) {
      setState(() => _healthScores = scores);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _saveSortPreference(SortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sortMode', mode.index);
  }

  Future<void> _saveViewPreference(ViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('viewMode', mode.index);
  }

  void _setViewMode(int index) {
    setState(() {
      _viewMode = index == 0 ? ViewMode.list : ViewMode.folder;
    });
    _saveViewPreference(_viewMode);
  }

  void _setSortMode(int index) {
    setState(() {
      _sortMode = index == 0 ? SortMode.lastOpened : SortMode.name;
    });
    _saveSortPreference(_sortMode);
  }

  List<Project> get _filteredProjects {
    var filtered = _projects.toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains(query) ||
        p.path.toLowerCase().contains(query) ||
        p.tags.any((t) => t.toLowerCase().contains(query)) ||
        (p.notes?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    // Filter by selected tag
    if (_selectedTag != null) {
      filtered = filtered.where((p) => p.tags.contains(_selectedTag)).toList();
    }

    // Filter by health
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

    // Filter by staleness
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

    // Sort by name or last opened
    if (_sortMode == SortMode.name) {
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      sorted.sort((a, b) {
        final aTime = a.lastOpenedAt ?? a.addedAt;
        final bTime = b.lastOpenedAt ?? b.addedAt;
        return bTime.compareTo(aTime);
      });
    }

    // Move pinned items to the top
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

  void _showYearInReview() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const YearReviewScreen()),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pinnedCount = _projects.where((p) => p.isPinned).length;

    return Scaffold(
      body: Column(
        children: [
          // Custom navbar
          UkNavbar(
            title: 'Project Launcher',
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.rocket_launch, color: cs.primary, size: 20),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.insights_rounded),
                onPressed: _showYearInReview,
                tooltip: 'Year in Review',
              ),
              IconButton(
                icon: const Icon(Icons.health_and_safety_rounded),
                onPressed: _showHealthDashboard,
                tooltip: 'Health Dashboard',
              ),
              IconButton(
                icon: const Icon(Icons.card_giftcard_rounded),
                onPressed: _showReferrals,
                tooltip: 'Referrals & Rewards',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.radar_rounded),
                onPressed: _scanForProjects,
                tooltip: 'Scan for projects',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadProjects,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 4),
              UkButton(
                label: 'Add',
                icon: Icons.add,
                size: UkButtonSize.small,
                onPressed: _addProjectManually,
              ),
            ],
          ),

          // Search and filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: UkSearchBar(
                    controller: _searchController,
                    hint: 'Search projects, tags, notes...',
                    size: UkSearchSize.small,
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 16),
                UkSubnav(
                  items: const ['List', 'Folder'],
                  selectedIndex: _viewMode == ViewMode.list ? 0 : 1,
                  onChanged: _setViewMode,
                  variant: UkSubnavVariant.pills,
                  wrap: false,
                ),
                const SizedBox(width: 8),
                UkSubnav(
                  items: const ['Recent', 'A-Z'],
                  selectedIndex: _sortMode == SortMode.lastOpened ? 0 : 1,
                  onChanged: _setSortMode,
                  variant: UkSubnavVariant.pills,
                  wrap: false,
                ),
              ],
            ),
          ),

          // Tags filter
          if (_allTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _TagFilterChip(
                      label: 'All',
                      isSelected: _selectedTag == null,
                      onTap: () => setState(() => _selectedTag = null),
                    ),
                    const SizedBox(width: 6),
                    ..._allTags.map((tag) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _TagFilterChip(
                        label: tag,
                        isSelected: _selectedTag == tag,
                        onTap: () => setState(() => _selectedTag = _selectedTag == tag ? null : tag),
                      ),
                    )),
                  ],
                ),
              ),
            ),

          // Health & Staleness filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Staleness filter
                _FilterChip(
                  icon: Icons.warning_amber_rounded,
                  label: 'Stale Only',
                  isSelected: _stalenessFilter == StalenessFilter.staleOnly,
                  color: Colors.orange,
                  onTap: () => setState(() {
                    _stalenessFilter = _stalenessFilter == StalenessFilter.staleOnly
                        ? StalenessFilter.all
                        : StalenessFilter.staleOnly;
                  }),
                ),
                const SizedBox(width: 8),
                // Health filters
                _FilterChip(
                  icon: Icons.favorite,
                  label: 'Healthy',
                  isSelected: _healthFilter == HealthFilter.healthy,
                  color: Colors.green,
                  onTap: () => setState(() {
                    _healthFilter = _healthFilter == HealthFilter.healthy
                        ? HealthFilter.all
                        : HealthFilter.healthy;
                  }),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  icon: Icons.healing,
                  label: 'Needs Attention',
                  isSelected: _healthFilter == HealthFilter.needsAttention,
                  color: Colors.orange,
                  onTap: () => setState(() {
                    _healthFilter = _healthFilter == HealthFilter.needsAttention
                        ? HealthFilter.all
                        : HealthFilter.needsAttention;
                  }),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  icon: Icons.error,
                  label: 'Critical',
                  isSelected: _healthFilter == HealthFilter.critical,
                  color: Colors.red,
                  onTap: () => setState(() {
                    _healthFilter = _healthFilter == HealthFilter.critical
                        ? HealthFilter.all
                        : HealthFilter.critical;
                  }),
                ),
              ],
            ),
          ),

          // Project count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_sortedProjects.length} project${_sortedProjects.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (pinnedCount > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.push_pin_rounded, size: 12, color: cs.primary),
                  const SizedBox(width: 2),
                  Text(
                    '$pinnedCount pinned',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                ],
                if (_searchQuery.isNotEmpty || _selectedTag != null) ...[
                  const SizedBox(width: 8),
                  UkBadge('filtered', variant: UkBadgeVariant.neutral),
                ],
              ],
            ),
          ),

          // Project list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _projects.isEmpty
                    ? _EmptyState(onAdd: _addProjectManually)
                    : _sortedProjects.isEmpty
                        ? _NoResultsState(query: _searchQuery)
                        : _viewMode == ViewMode.list
                            ? ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _sortedProjects.length,
                                itemBuilder: (context, index) {
                                  final project = _sortedProjects[index];
                                  return _ProjectCard(
                                    project: project,
                                    healthScore: _healthScores[project.path],
                                    onRemove: () => _removeProject(project),
                                    onOpenTerminal: () => _openInTerminal(project),
                                    onOpenVSCode: () => _openInVSCode(project),
                                    onTogglePin: () => _togglePin(project),
                                    onEditTags: () => _editTags(project),
                                    onEditNotes: () => _editNotes(project),
                                  );
                                },
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _groupedProjects.length,
                                itemBuilder: (context, index) {
                                  final folderName = _groupedProjects.keys.elementAt(index);
                                  final projects = _groupedProjects[folderName]!;
                                  return _FolderGroup(
                                    folderName: folderName,
                                    projects: projects,
                                    healthScores: _healthScores,
                                    onRemove: _removeProject,
                                    onOpenTerminal: _openInTerminal,
                                    onOpenVSCode: _openInVSCode,
                                    onTogglePin: _togglePin,
                                    onEditTags: _editTags,
                                    onEditNotes: _editNotes,
                                  );
                                },
                              ),
          ),
        ],
      ),
    );
  }
}

class _TagFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isSelected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : cs.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isSelected ? color : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final Project project;
  final CachedHealthScore? healthScore;
  final VoidCallback onRemove;
  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenVSCode;
  final VoidCallback onTogglePin;
  final VoidCallback onEditTags;
  final VoidCallback onEditNotes;

  const _ProjectCard({
    required this.project,
    this.healthScore,
    required this.onRemove,
    required this.onOpenTerminal,
    required this.onOpenVSCode,
    required this.onTogglePin,
    required this.onEditTags,
    required this.onEditNotes,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final project = widget.project;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _isHovered ? cs.surfaceContainerHighest : cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: project.isPinned
                ? cs.primary.withValues(alpha: 0.5)
                : _isHovered
                    ? cs.primary.withValues(alpha: 0.3)
                    : cs.outline.withValues(alpha: 0.2),
            width: project.isPinned ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Pin indicator & Folder icon
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(Icons.folder_rounded, color: cs.primary, size: 24),
                      ),
                      if (project.isPinned)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.push_pin_rounded, color: cs.onPrimary, size: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Project info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                project.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Staleness badge
                            if (widget.healthScore != null &&
                                widget.healthScore!.staleness != StalenessLevel.fresh)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _StalenessBadge(staleness: widget.healthScore!.staleness),
                              ),
                            // Health score indicator
                            if (widget.healthScore != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _HealthScoreIndicator(
                                  score: widget.healthScore!.details.totalScore,
                                ),
                              ),
                            if (project.notes != null && project.notes!.isNotEmpty)
                              Tooltip(
                                message: project.notes!,
                                child: Icon(Icons.sticky_note_2_rounded, size: 16, color: cs.tertiary),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.path,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (project.lastOpenedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Last opened ${_formatTimeAgo(project.lastOpenedAt!)}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Action buttons
                  AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.6,
                    duration: const Duration(milliseconds: 150),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          icon: project.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                          tooltip: project.isPinned ? 'Unpin' : 'Pin to top',
                          color: project.isPinned ? cs.primary : cs.onSurfaceVariant,
                          onPressed: widget.onTogglePin,
                        ),
                        const SizedBox(width: 6),
                        _ActionButton(
                          icon: Icons.terminal_rounded,
                          tooltip: 'Open in Terminal',
                          color: Colors.orange,
                          onPressed: widget.onOpenTerminal,
                        ),
                        const SizedBox(width: 6),
                        _ActionButton(
                          icon: Icons.code_rounded,
                          tooltip: 'Open in VS Code',
                          color: cs.primary,
                          onPressed: widget.onOpenVSCode,
                        ),
                        const SizedBox(width: 6),
                        _ActionButton(
                          icon: Icons.folder_open_rounded,
                          tooltip: 'Open in Finder',
                          color: cs.tertiary,
                          onPressed: () => LauncherService.openInFinder(project.path),
                        ),
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant, size: 18),
                          tooltip: 'More options',
                          onSelected: (value) {
                            switch (value) {
                              case 'tags':
                                widget.onEditTags();
                              case 'notes':
                                widget.onEditNotes();
                              case 'remove':
                                widget.onRemove();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'tags',
                              child: Row(
                                children: [
                                  Icon(Icons.label_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit tags'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'notes',
                              child: Row(
                                children: [
                                  Icon(Icons.sticky_note_2_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit notes'),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18, color: cs.error),
                                  const SizedBox(width: 8),
                                  Text('Remove', style: TextStyle(color: cs.error)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Tags row
              if (project.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: project.tags.map((tag) => UkBadge(tag, variant: UkBadgeVariant.neutral)).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _StalenessBadge extends StatelessWidget {
  final StalenessLevel staleness;

  const _StalenessBadge({required this.staleness});

  @override
  Widget build(BuildContext context) {
    final color = _getStalenessColor(staleness);
    return Tooltip(
      message: staleness.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              staleness == StalenessLevel.abandoned
                  ? Icons.archive_rounded
                  : Icons.access_time_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              staleness.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStalenessColor(StalenessLevel staleness) {
    switch (staleness) {
      case StalenessLevel.fresh:
        return Colors.green;
      case StalenessLevel.warning:
        return Colors.orange;
      case StalenessLevel.stale:
        return Colors.red;
      case StalenessLevel.abandoned:
        return Colors.grey;
    }
  }
}

class _HealthScoreIndicator extends StatelessWidget {
  final int score;

  const _HealthScoreIndicator({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);
    return Tooltip(
      message: 'Health Score: $score/100',
      child: SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: score / 100,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
              strokeWidth: 2.5,
            ),
            Text(
              score.toString(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 8,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}

class _FolderGroup extends StatelessWidget {
  final String folderName;
  final List<Project> projects;
  final Map<String, CachedHealthScore> healthScores;
  final Function(Project) onRemove;
  final Function(Project) onOpenTerminal;
  final Function(Project) onOpenVSCode;
  final Function(Project) onTogglePin;
  final Function(Project) onEditTags;
  final Function(Project) onEditNotes;

  const _FolderGroup({
    required this.folderName,
    required this.projects,
    required this.healthScores,
    required this.onRemove,
    required this.onOpenTerminal,
    required this.onOpenVSCode,
    required this.onTogglePin,
    required this.onEditTags,
    required this.onEditNotes,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Row(
            children: [
              Icon(Icons.folder_rounded, color: cs.tertiary, size: 18),
              const SizedBox(width: 8),
              Text(
                folderName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              UkBadge('${projects.length}', variant: UkBadgeVariant.neutral),
            ],
          ),
        ),
        ...projects.map((project) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _ProjectCard(
            project: project,
            healthScore: healthScores[project.path],
            onRemove: () => onRemove(project),
            onOpenTerminal: () => onOpenTerminal(project),
            onOpenVSCode: () => onOpenVSCode(project),
            onTogglePin: () => onTogglePin(project),
            onEditTags: () => onEditTags(project),
            onEditNotes: () => onEditNotes(project),
          ),
        )),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              size: 48,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No projects yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first project to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'addproject /path/to/project',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          UkButton(
            label: 'Add Project',
            icon: Icons.add,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  final String query;

  const _NoResultsState({required this.query});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

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
  ScanResult? _result;
  final _customPathController = TextEditingController();

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
    });

    final result = await ProjectScanner.scanAndAddProjects(
      onProgress: (path) {
        if (mounted) {
          setState(() => _currentPath = path);
        }
      },
      onFound: (count) {
        if (mounted) {
          setState(() => _foundCount = count);
        }
      },
    );

    if (mounted) {
      setState(() {
        _isScanning = false;
        _isDone = true;
        _result = result;
      });
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

  Future<void> _browseFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder to scan',
    );
    if (result != null) {
      _customPathController.text = result;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scanPaths = ProjectScanner.getScanPaths();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.radar_rounded, color: cs.primary),
          const SizedBox(width: 12),
          const Text('Scan for Projects'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: _isDone
            ? _buildResultView(cs)
            : _isScanning
                ? _buildScanningView(cs)
                : _buildStartView(cs, scanPaths),
      ),
      actions: [
        if (_isDone)
          UkButton(
            label: 'Done',
            variant: UkButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(_result),
          )
        else if (!_isScanning) ...[
          UkButton(
            label: 'Cancel',
            variant: UkButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UkButton(
            label: 'Scan Default Paths',
            variant: UkButtonVariant.primary,
            icon: Icons.radar_rounded,
            onPressed: _startScan,
          ),
        ],
      ],
    );
  }

  Widget _buildStartView(ColorScheme cs, List<String> scanPaths) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Automatically find git repositories in common project directories.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Default scan locations:',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView(
            children: scanPaths.map((path) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Directory(path).existsSync() ? Icons.folder_rounded : Icons.folder_off_rounded,
                    size: 16,
                    color: Directory(path).existsSync() ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path.replaceFirst(Platform.environment['HOME'] ?? '', '~'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Directory(path).existsSync() ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 16),
        const UkDivider(),
        const SizedBox(height: 16),
        Text(
          'Or scan a custom directory:',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: UkTextField(
                controller: _customPathController,
                hint: '/path/to/scan',
                prefixIcon: Icons.folder_rounded,
                size: UkFieldSize.small,
              ),
            ),
            const SizedBox(width: 8),
            UkButton(
              label: 'Browse',
              size: UkButtonSize.small,
              variant: UkButtonVariant.text,
              icon: Icons.folder_open_rounded,
              onPressed: _browseFolder,
            ),
            const SizedBox(width: 8),
            UkButton(
              label: 'Scan',
              size: UkButtonSize.small,
              variant: UkButtonVariant.outline,
              onPressed: _scanCustomPath,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScanningView(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Scanning for git repositories...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _currentPath.replaceFirst(Platform.environment['HOME'] ?? '', '~'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        Text(
          '$_foundCount repositories found',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 24),
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
            color: cs.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Scan Complete',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ResultStat(
              label: 'Found',
              value: result.totalFound.toString(),
              icon: Icons.folder_rounded,
              color: cs.primary,
            ),
            _ResultStat(
              label: 'Added',
              value: result.newlyAdded.toString(),
              icon: Icons.add_circle_rounded,
              color: Colors.green,
            ),
            _ResultStat(
              label: 'Already exists',
              value: result.alreadyExists.toString(),
              icon: Icons.check_circle_outline,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
