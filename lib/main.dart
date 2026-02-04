import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/project.dart';
import 'services/project_storage.dart';
import 'services/launcher_service.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadProjects();
    // Auto-refresh every 2 seconds to pick up new projects from terminal
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadProjects();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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

  void _toggleSortMode() {
    setState(() {
      _sortMode = _sortMode == SortMode.lastOpened
          ? SortMode.name
          : SortMode.lastOpened;
    });
    _saveSortPreference(_sortMode);
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == ViewMode.list
          ? ViewMode.folder
          : ViewMode.list;
    });
    _saveViewPreference(_viewMode);
  }

  List<Project> get _sortedProjects {
    final sorted = List<Project>.from(_projects);
    if (_sortMode == SortMode.name) {
      sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      // Sort by last opened (most recent first), fallback to addedAt
      sorted.sort((a, b) {
        final aTime = a.lastOpenedAt ?? a.addedAt;
        final bTime = b.lastOpenedAt ?? b.addedAt;
        return bTime.compareTo(aTime); // Descending order
      });
    }
    return sorted;
  }

  // Group projects by parent folder
  Map<String, List<Project>> get _groupedProjects {
    final groups = <String, List<Project>>{};
    for (final project in _sortedProjects) {
      final parentPath = project.path.substring(0, project.path.lastIndexOf('/'));
      final parentName = parentPath.split('/').last;
      groups.putIfAbsent(parentName, () => []).add(project);
    }
    // Sort group keys
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
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter project path',
            labelText: 'Path',
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Launcher'),
        actions: [
          // View toggle
          _ToggleChip(
            label: _viewMode == ViewMode.list ? 'List' : 'Folder',
            icon: _viewMode == ViewMode.list ? Icons.list : Icons.folder_copy,
            tooltip: 'Show by: ${_viewMode == ViewMode.list ? 'List' : 'Folder'}',
            onPressed: _toggleViewMode,
          ),
          const SizedBox(width: 4),
          // Sort toggle
          _ToggleChip(
            label: _sortMode == SortMode.lastOpened ? 'Recent' : 'Name',
            icon: _sortMode == SortMode.lastOpened ? Icons.access_time : Icons.sort_by_alpha,
            tooltip: 'Sort by: ${_sortMode == SortMode.lastOpened ? 'Last Opened' : 'Name'}',
            onPressed: _toggleSortMode,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProjects,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addProjectManually,
            tooltip: 'Add project manually',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No projects yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Run "addproject" in terminal to add a project',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addProjectManually,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Manually'),
                      ),
                    ],
                  ),
                )
              : _viewMode == ViewMode.list
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sortedProjects.length,
                      itemBuilder: (context, index) {
                        final project = _sortedProjects[index];
                        return ProjectCard(
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
    );
  }
}

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onRemove;
  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenVSCode;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onRemove,
    required this.onOpenTerminal,
    required this.onOpenVSCode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Folder icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder, color: Colors.blue, size: 28),
            ),
            const SizedBox(width: 16),
            // Project info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project.path,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  icon: Icons.terminal,
                  tooltip: 'Open in Terminal',
                  color: Colors.orange,
                  onPressed: onOpenTerminal,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.code,
                  tooltip: 'Open in VS Code',
                  color: Colors.blue,
                  onPressed: onOpenVSCode,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.folder_open,
                  tooltip: 'Open in Finder',
                  color: Colors.grey,
                  onPressed: () => LauncherService.openInFinder(project.path),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Remove from list',
                  color: Colors.red,
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
          child: Row(
            children: [
              Icon(Icons.folder, color: Colors.amber[600], size: 20),
              const SizedBox(width: 8),
              Text(
                folderName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${projects.length}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        ),
        ...projects.map((project) => Padding(
          padding: const EdgeInsets.only(left: 12),
          child: ProjectCard(
            project: project,
            onRemove: () => onRemove(project),
            onOpenTerminal: () => onOpenTerminal(project),
            onOpenVSCode: () => onOpenVSCode(project),
          ),
        )),
        const SizedBox(height: 8),
      ],
    );
  }
}
