import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../models/health_score.dart';
import '../../services/launcher_service.dart';
import '../../theme/app_theme.dart';

class ProjectCard extends StatefulWidget {
  final Project project;
  final CachedHealthScore? healthScore;
  final VoidCallback onRemove;
  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenVSCode;
  final VoidCallback onTogglePin;
  final VoidCallback onEditTags;
  final VoidCallback onEditNotes;

  const ProjectCard({
    super.key,
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
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _isHovered = false;

  String get _languageTag {
    final hs = widget.healthScore;
    if (hs != null && hs.details.dependencyFileType != null) {
      return _depTypeToLanguage(hs.details.dependencyFileType!);
    }
    return '';
  }

  static String _depTypeToLanguage(String depType) {
    switch (depType) {
      case 'pubspec.yaml': return 'Flutter';
      case 'package.json': return 'NodeJS';
      case 'requirements.txt':
      case 'setup.py':
      case 'pyproject.toml': return 'Python';
      case 'Cargo.toml': return 'Rust';
      case 'go.mod': return 'Go';
      case 'Gemfile': return 'Ruby';
      case 'composer.json': return 'PHP';
      case 'build.gradle':
      case 'build.gradle.kts': return 'Kotlin';
      case 'pom.xml': return 'Java';
      default: return '';
    }
  }

  String _formatStaleness() {
    final hs = widget.healthScore;
    if (hs == null) return '';
    final lastCommit = hs.details.lastCommitDate;
    if (lastCommit == null) return '';
    final days = DateTime.now().difference(lastCommit).inDays;
    if (days < 30) return '';
    if (days >= 180) return '180d+ Inactive';
    return '${days}d Inactive';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final project = widget.project;
    final lang = _languageTag;
    final staleness = _formatStaleness();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovered
              ? cs.surfaceContainerHighest
              : cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: project.isPinned
                ? AppColors.accent.withValues(alpha: 0.4)
                : _isHovered
                    ? cs.outline.withValues(alpha: 0.5)
                    : cs.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            // Project info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Project name
                      Text(
                        project.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      if (project.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Path
                  Text(
                    _shortenPath(project.path),
                    style: AppTypography.mono(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Tags row
                  Row(
                    children: [
                      if (lang.isNotEmpty)
                        _LanguageTag(language: lang),
                      if (staleness.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          staleness,
                          style: AppTypography.mono(
                            fontSize: 11,
                            color: _stalenessColor(),
                          ),
                        ),
                      ],
                      if (project.tags.isNotEmpty) ...[
                        if (lang.isNotEmpty || staleness.isNotEmpty)
                          const SizedBox(width: 8),
                        ...project.tags.take(2).map((tag) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              tag,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons
            AnimatedOpacity(
              opacity: _isHovered ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 150),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIcon(
                    icon: Icons.terminal_rounded,
                    tooltip: 'Open in Terminal',
                    onPressed: widget.onOpenTerminal,
                  ),
                  _ActionIcon(
                    icon: Icons.code_rounded,
                    tooltip: 'Open in VS Code',
                    onPressed: widget.onOpenVSCode,
                  ),
                  _ActionIcon(
                    icon: Icons.folder_open_rounded,
                    tooltip: 'Open in Finder',
                    onPressed: () => LauncherService.openInFinder(project.path),
                  ),
                  _ActionIcon(
                    icon: project.isPinned ? Icons.star_rounded : Icons.star_border_rounded,
                    tooltip: project.isPinned ? 'Unpin' : 'Pin',
                    color: project.isPinned ? AppColors.accent : null,
                    onPressed: widget.onTogglePin,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _stalenessColor() {
    final hs = widget.healthScore;
    if (hs == null) return Colors.grey;
    switch (hs.staleness) {
      case StalenessLevel.fresh: return AppColors.success;
      case StalenessLevel.warning: return AppColors.warning;
      case StalenessLevel.stale: return AppColors.error;
      case StalenessLevel.abandoned: return Colors.grey;
    }
  }

  String _shortenPath(String path) {
    final home = '/Users/${path.split('/')[2]}';
    if (path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }
}

class _LanguageTag extends StatelessWidget {
  final String language;

  const _LanguageTag({required this.language});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getLanguageColor(language);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        language,
        style: AppTypography.mono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color ?? cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
