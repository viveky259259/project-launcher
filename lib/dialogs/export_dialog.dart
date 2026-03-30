import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:launcher_models/launcher_models.dart';
import 'package:launcher_theme/launcher_theme.dart';
import '../services/export_service.dart';
import '../services/fresh_push_service.dart';
import '../services/platform_helper.dart';

class ExportDialog extends StatefulWidget {
  final List<Project> projects;
  const ExportDialog({super.key, required this.projects});

  @override
  State<ExportDialog> createState() => ExportDialogState();
}

class ExportDialogState extends State<ExportDialog> {
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
  final _commitMsgController = TextEditingController(
    text: 'Initial commit — fresh export',
  );
  final _exportSearchController = TextEditingController();
  String _exportSearchQuery = '';
  bool _pushConfig = true;

  @override
  void initState() {
    super.initState();
    _selected = {for (final p in widget.projects) p.path: true};
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
          onPressed: _remoteUrlController.text.trim().isNotEmpty
              ? _startPush
              : null,
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
          child: Text('Save ZIP to Desktop'),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
              Icon(
                Icons.search_rounded,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
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
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
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
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Project list (filtered by search)
        Builder(
          builder: (context) {
            final query = _exportSearchQuery.toLowerCase();
            final filtered = widget.projects
                .where(
                  (p) =>
                      query.isEmpty ||
                      p.name.toLowerCase().contains(query) ||
                      p.path.toLowerCase().contains(query),
                )
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
                      child: Text(
                        'No projects match "$_exportSearchQuery"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final project = filtered[index];
                        final isSelected = _selected[project.path] ?? false;
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) => setState(
                            () => _selected[project.path] = val ?? false,
                          ),
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
          },
        ),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            Tooltip(
              message:
                  'Including .git directories preserves full history but increases file size significantly',
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.error),
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
    final progress = _totalProjects > 0
        ? _currentProject / _totalProjects
        : 0.0;
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                  Icon(
                    Icons.folder_zip_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      PlatformHelper.shortenPath(result.zipPath),
                      style: AppTypography.mono(
                        fontSize: 12,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.data_usage_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.fileSizeFormatted,
                    style: AppTypography.mono(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            Tooltip(
              message:
                  'Pushes a projects.json with name and path for every project in your dashboard',
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
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
                    Icon(
                      Icons.account_tree_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(
                      Icons.folder_copy_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.error),
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
    final progress = _totalProjects > 0
        ? _currentProject / _totalProjects
        : 0.0;
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
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _pushLogScrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                          Text(
                            entry.icon,
                            style: const TextStyle(fontSize: 12),
                          ),
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
                                        color: cs.onSurfaceVariant.withValues(
                                          alpha: 0.6,
                                        ),
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
                subtitle = r.parts > 1 ? 'Uploaded in ${r.parts} parts' : null;
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
                    color: r.skipped ? cs.onSurfaceVariant : cs.onSurface,
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
