import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/project.dart';
import 'services/project_storage.dart';
import 'services/launcher_service.dart';
import 'theme.dart';
import 'kit/kit.dart';

enum SortMode { lastOpened, name }
enum ViewMode { list, folder }

void main() {
  runApp(const ProjectLauncherApp());
}

class ProjectLauncherApp extends StatelessWidget {
  const ProjectLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Launcher',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
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
  bool _isLoading = true;
  Timer? _refreshTimer;
  SortMode _sortMode = SortMode.lastOpened;
  ViewMode _viewMode = ViewMode.list;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadProjects();
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
    if (_searchQuery.isEmpty) return _projects;
    final query = _searchQuery.toLowerCase();
    return _projects.where((p) =>
      p.name.toLowerCase().contains(query) ||
      p.path.toLowerCase().contains(query)
    ).toList();
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
    if (mounted) {
      setState(() {
        _projects = projects;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                    hint: 'Search projects...',
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
                if (_searchQuery.isNotEmpty) ...[
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
                                    onRemove: () => _removeProject(project),
                                    onOpenTerminal: () => _openInTerminal(project),
                                    onOpenVSCode: () => _openInVSCode(project),
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
                                    onRemove: _removeProject,
                                    onOpenTerminal: _openInTerminal,
                                    onOpenVSCode: _openInVSCode,
                                  );
                                },
                              ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final Project project;
  final VoidCallback onRemove;
  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenVSCode;

  const _ProjectCard({
    required this.project,
    required this.onRemove,
    required this.onOpenTerminal,
    required this.onOpenVSCode,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            color: _isHovered ? cs.primary.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Folder icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.folder_rounded, color: cs.primary, size: 24),
              ),
              const SizedBox(width: 16),
              // Project info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.project.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.project.path,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.project.lastOpenedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last opened ${_formatTimeAgo(widget.project.lastOpenedAt!)}',
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
                      onPressed: () => LauncherService.openInFinder(widget.project.path),
                    ),
                    const SizedBox(width: 6),
                    _ActionButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Remove',
                      color: cs.error,
                      onPressed: widget.onRemove,
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

class _FolderGroup extends StatelessWidget {
  final String folderName;
  final List<Project> projects;
  final Function(Project) onRemove;
  final Function(Project) onOpenTerminal;
  final Function(Project) onOpenVSCode;

  const _FolderGroup({
    required this.folderName,
    required this.projects,
    required this.onRemove,
    required this.onOpenTerminal,
    required this.onOpenVSCode,
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
            onRemove: () => onRemove(project),
            onOpenTerminal: () => onOpenTerminal(project),
            onOpenVSCode: () => onOpenVSCode(project),
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
