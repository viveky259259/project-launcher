import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/health_score.dart';
import '../services/health_service.dart';
import '../services/project_storage.dart';
import '../theme/app_theme.dart';

class ProjectSettingsScreen extends StatefulWidget {
  final Project project;
  final CachedHealthScore? healthScore;
  final VoidCallback onSaved;
  final VoidCallback onRemoved;

  const ProjectSettingsScreen({
    super.key,
    required this.project,
    this.healthScore,
    required this.onSaved,
    required this.onRemoved,
  });

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late List<String> _tags;
  String _activeSection = 'general';
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _notesController = TextEditingController(text: widget.project.notes ?? '');
    _tags = List.from(widget.project.tags);

    _nameController.addListener(_markChanged);
    _notesController.addListener(_markChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _save() async {
    final projects = await ProjectStorage.loadProjects();
    final index = projects.indexWhere((p) => p.path == widget.project.path);
    if (index == -1) return;

    projects[index] = projects[index].copyWith(
      tags: _tags,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      clearNotes: _notesController.text.isEmpty,
    );

    await ProjectStorage.saveProjects(projects);
    widget.onSaved();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved'), behavior: SnackBarBehavior.floating),
      );
      setState(() => _hasChanges = false);
    }
  }

  Future<void> _removeProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: const Text('Remove Project?'),
          content: Text(
            'This will remove "${widget.project.name}" from Project Launcher. Your local files will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final projects = await ProjectStorage.loadProjects();
      projects.removeWhere((p) => p.path == widget.project.path);
      await ProjectStorage.saveProjects(projects);
      widget.onRemoved();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _addTag() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: const Text('Add Tag'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Tag name',
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.of(ctx).pop(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ).then((tag) {
      if (tag != null && tag is String && !_tags.contains(tag)) {
        setState(() {
          _tags.add(tag);
          _hasChanges = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = widget.healthScore?.details;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          // Settings sub-nav sidebar
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(right: BorderSide(color: cs.outline.withValues(alpha: 0.3))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to Dashboard'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                      textStyle: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w500),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _NavItem(
                  label: 'General Settings',
                  icon: Icons.settings_rounded,
                  isActive: _activeSection == 'general',
                  onTap: () => setState(() => _activeSection = 'general'),
                ),
                _NavItem(
                  label: 'Health Rules',
                  icon: Icons.favorite_rounded,
                  isActive: _activeSection == 'health',
                  onTap: () => setState(() => _activeSection = 'health'),
                ),
                _NavItem(
                  label: 'Environment',
                  icon: Icons.terminal_rounded,
                  isActive: _activeSection == 'environment',
                  onTap: () => setState(() => _activeSection = 'environment'),
                ),
                _NavItem(
                  label: 'Danger Zone',
                  icon: Icons.warning_amber_rounded,
                  isActive: _activeSection == 'danger',
                  onTap: () => setState(() => _activeSection = 'danger'),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    children: [
                      // Project avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Center(
                          child: Text(
                            widget.project.name.substring(0, widget.project.name.length >= 2 ? 2 : 1).toUpperCase(),
                            style: AppTypography.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.project.name,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (score != null) ...[
                                  const SizedBox(width: 12),
                                  _HealthBadge(category: score.category),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${score.totalScore}/100',
                                    style: AppTypography.mono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_hasChanges) ...[
                        TextButton(
                          onPressed: () {
                            _nameController.text = widget.project.name;
                            _notesController.text = widget.project.notes ?? '';
                            _tags = List.from(widget.project.tags);
                            setState(() => _hasChanges = false);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                            textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Discard'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _save,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
                            ),
                            textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ],
                  ),
                ),

                // Content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildSection(cs),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ColorScheme cs) {
    switch (_activeSection) {
      case 'health':
        return _buildHealthSection(cs);
      case 'environment':
        return _buildEnvironmentSection(cs);
      case 'danger':
        return _buildDangerSection(cs);
      default:
        return _buildGeneralSection(cs);
    }
  }

  Widget _buildGeneralSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Project Identity
        _SectionHeader(title: 'Project Identity'),
        const SizedBox(height: 16),
        _FieldLabel(label: 'Display Name'),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          enabled: false,
          decoration: _inputDecoration(cs, hint: 'Project name'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: 16),
        _FieldLabel(label: 'Project Path'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.project.path,
                  style: AppTypography.mono(fontSize: 13, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.folder_open_rounded, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Tags & Categorization
        _SectionHeader(title: 'Tags & Categorization'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map((tag) => _TagChip(
              label: tag,
              onRemove: () {
                setState(() {
                  _tags.remove(tag);
                  _hasChanges = true;
                });
              },
            )),
            ActionChip(
              label: Text(
                '+ Add Tag',
                style: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
              onPressed: _addTag,
              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _FieldLabel(label: 'Project Notes'),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 4,
          decoration: _inputDecoration(cs, hint: 'Add notes about this project...'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
        ),
      ],
    );
  }

  Widget _buildHealthSection(ColorScheme cs) {
    final score = widget.healthScore?.details;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Health Overview'),
        const SizedBox(height: 16),
        if (score != null) ...[
          _HealthRow(label: 'Git Activity', score: score.gitScore, maxScore: 40),
          const SizedBox(height: 12),
          _HealthRow(label: 'Dependencies', score: score.depsScore, maxScore: 30),
          const SizedBox(height: 12),
          _HealthRow(label: 'Tests', score: score.testsScore, maxScore: 30),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Details', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 12),
                _DetailRow(label: 'Recent commits', value: score.hasRecentCommits),
                _DetailRow(label: 'No uncommitted changes', value: score.noUncommittedChanges),
                _DetailRow(label: 'No unpushed commits', value: score.noUnpushedCommits),
                _DetailRow(label: 'Has dependency file', value: score.hasDependencyFile),
                _DetailRow(label: 'Has lock file', value: score.hasLockFile),
                _DetailRow(label: 'Has test folder', value: score.hasTestFolder),
                _DetailRow(label: 'Has test files', value: score.hasTestFiles),
              ],
            ),
          ),
        ] else
          Text(
            'No health data available. Run a health check from the dashboard.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _buildEnvironmentSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Quick Launch'),
        const SizedBox(height: 16),
        _SettingRow(
          label: 'Primary Terminal',
          value: 'Terminal.app (Default)',
          icon: Icons.terminal_rounded,
        ),
        const SizedBox(height: 12),
        _SettingRow(
          label: 'Editor',
          value: 'VS Code',
          icon: Icons.code_rounded,
        ),
        const SizedBox(height: 24),
        Text(
          'Terminal and editor detection is automatic. Custom configuration coming in a future update.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildDangerSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Danger Zone', color: AppColors.error),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remove Project',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Removing the project from Launcher will not delete the local files. You can always re-add it later by scanning or browsing.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _removeProject,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  textStyle: AppTypography.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('Remove Project'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(ColorScheme cs, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.mono(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
      filled: true,
      fillColor: cs.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );
  }
}

// -- Sub-widgets --

class _NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accent.withValues(alpha: 0.15)
                : _isHovered
                    ? cs.onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isActive ? AppColors.accent : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: AppTypography.inter(
                  fontSize: 13,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isActive ? AppColors.accent : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionHeader({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = AppColors.languageColors[label] ?? AppColors.accent;

    return Chip(
      label: Text(
        label,
        style: AppTypography.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
      deleteIcon: Icon(Icons.close, size: 14, color: color),
      onDeleted: onRemove,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final HealthCategory category;
  const _HealthBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (category) {
      case HealthCategory.healthy:
        color = AppColors.success;
      case HealthCategory.needsAttention:
        color = AppColors.warning;
      case HealthCategory.critical:
        color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        category.label,
        style: AppTypography.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final int score;
  final int maxScore;

  const _HealthRow({required this.label, required this.score, required this.maxScore});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = maxScore > 0 ? score / maxScore : 0.0;
    Color barColor;
    if (fraction >= 0.8) {
      barColor = AppColors.success;
    } else if (fraction >= 0.5) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.error;
    }

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: cs.outline.withValues(alpha: 0.1),
              color: barColor,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            '$score/$maxScore',
            textAlign: TextAlign.right,
            style: AppTypography.mono(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final bool value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: value ? AppColors.success : cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SettingRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface)),
            ],
          ),
        ],
      ),
    );
  }
}
