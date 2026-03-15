import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../models/health_score.dart';
import '../../services/launcher_service.dart';
import '../../services/platform_helper.dart';
import '../../services/project_type_detector.dart';
import '../../theme/app_theme.dart';

class ProjectCard extends StatefulWidget {
  final Project project;
  final CachedHealthScore? healthScore;
  final ProjectStack projectStack;
  final bool isGitRepo;
  final bool hasUnpushed;
  final bool hasUncommitted;
  final String? branchName;
  final VoidCallback onRemove;
  final VoidCallback onOpenTerminal;
  final VoidCallback onOpenVSCode;
  final VoidCallback onTogglePin;
  final VoidCallback onEditTags;
  final VoidCallback onEditNotes;
  final VoidCallback? onSettings;
  final bool hasAIInsights;
  final String? version;

  const ProjectCard({
    super.key,
    required this.project,
    this.healthScore,
    this.projectStack = const ProjectStack(primary: ProjectType.unknown),
    this.isGitRepo = false,
    this.hasUnpushed = false,
    this.hasUncommitted = false,
    this.branchName,
    required this.onRemove,
    required this.onOpenTerminal,
    required this.onOpenVSCode,
    required this.onTogglePin,
    required this.onEditTags,
    required this.onEditNotes,
    this.onSettings,
    this.hasAIInsights = false,
    this.version,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _isHovered = false;

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

  String _relativeTime() {
    final hs = widget.healthScore;
    if (hs == null) return '';
    final lastCommit = hs.details.lastCommitDate;
    if (lastCommit == null) return '';
    final diff = DateTime.now().difference(lastCommit);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  Color _activityDotColor() {
    final hs = widget.healthScore;
    if (hs == null) return Colors.transparent;
    final lastCommit = hs.details.lastCommitDate;
    if (lastCommit == null) return Colors.transparent;
    final days = DateTime.now().difference(lastCommit).inDays;
    if (days <= 1) return AppColors.success;       // today/yesterday
    if (days <= 7) return AppColors.accent;         // this week
    if (days <= 30) return AppColors.warning;       // this month
    return Colors.transparent;                       // older — no dot
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final project = widget.project;
    final stack = widget.projectStack;
    final staleness = _formatStaleness();
    final relTime = _relativeTime();
    final dotColor = _activityDotColor();

    return GestureDetector(
      onTap: widget.onSettings,
      child: MouseRegion(
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
            // Stacked project type icon with activity dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                _StackedIcon(stack: stack),
                if (dotColor != Colors.transparent)
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Project info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          project.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (project.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                      ],
                      if (relTime.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          relTime,
                          style: AppTypography.mono(
                            fontSize: 11,
                            color: dotColor != Colors.transparent
                                ? dotColor.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Path + branch + micro indicators
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _shortenPath(project.path),
                          style: AppTypography.mono(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.branchName != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.fork_right_rounded, size: 12, color: AppColors.accent.withValues(alpha: 0.7)),
                        const SizedBox(width: 2),
                        Text(
                          widget.branchName!,
                          style: AppTypography.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                      if (widget.healthScore != null) ...[
                        const SizedBox(width: 8),
                        _MicroHealthDot(score: widget.healthScore!.details.totalScore),
                      ],
                      if (widget.hasUncommitted) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Uncommitted changes',
                          child: Icon(Icons.edit_note_rounded, size: 14, color: AppColors.warning.withValues(alpha: 0.8)),
                        ),
                      ],
                      if (widget.hasUnpushed) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Unpushed commits',
                          child: Icon(Icons.cloud_upload_outlined, size: 13, color: AppColors.warning.withValues(alpha: 0.8)),
                        ),
                      ],
                      if (widget.hasAIInsights) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Has AI insights',
                          child: Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.accent.withValues(alpha: 0.8)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Git status + Tech stack badges + staleness + tags
                  Row(
                    children: [
                      // Git icon
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _GitBadge(
                          isGitRepo: widget.isGitRepo,
                          hasUnpushed: widget.hasUnpushed,
                        ),
                      ),
                      // All tech badges
                      ...stack.all.map((type) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _TechBadge(type: type),
                      )),
                      if (staleness.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          staleness,
                          style: AppTypography.mono(
                            fontSize: 11,
                            color: _stalenessColor(),
                          ),
                        ),
                      ],
                      if (project.tags.isNotEmpty) ...[
                        if (stack.all.isNotEmpty || staleness.isNotEmpty)
                          const SizedBox(width: 4),
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
                      if (widget.version != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            'v${widget.version}',
                            style: AppTypography.mono(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent),
                          ),
                        ),
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
                  if (widget.onSettings != null)
                    _ActionIcon(
                      icon: Icons.settings_rounded,
                      tooltip: 'Project Settings',
                      onPressed: widget.onSettings!,
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
    return PlatformHelper.shortenPath(path);
  }
}

/// Stacked icon: primary icon with optional secondary overlay badge
class _StackedIcon extends StatelessWidget {
  final ProjectStack stack;

  const _StackedIcon({required this.stack});

  @override
  Widget build(BuildContext context) {
    final primary = stack.primary;

    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Primary icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primary.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              primary.icon,
              size: 20,
              color: primary.color,
            ),
          ),

          // Secondary badge (first secondary only, bottom-right)
          if (stack.secondary.isNotEmpty)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: stack.secondary.first.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: stack.secondary.first.color.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  stack.secondary.first.icon,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),

          // Third tech indicator dot (if 2+ secondaries)
          if (stack.secondary.length >= 2)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: stack.secondary[1].color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tiny health score dot with tooltip
class _MicroHealthDot extends StatelessWidget {
  final int score;
  const _MicroHealthDot({required this.score});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (score >= 80) {
      color = AppColors.success;
    } else if (score >= 50) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }

    return Tooltip(
      message: 'Health: $score/100',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '$score',
            style: AppTypography.mono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Git status badge
class _GitBadge extends StatelessWidget {
  final bool isGitRepo;
  final bool hasUnpushed;

  const _GitBadge({required this.isGitRepo, required this.hasUnpushed});

  @override
  Widget build(BuildContext context) {
    final color = isGitRepo
        ? (hasUnpushed ? AppColors.warning : AppColors.success)
        : const Color(0xFF6B7280);
    final label = isGitRepo
        ? (hasUnpushed ? 'Unpushed' : 'Git')
        : 'No Git';
    final icon = isGitRepo
        ? (hasUnpushed ? Icons.cloud_upload_outlined : Icons.check_circle_outline_rounded)
        : Icons.cancel_outlined;

    return Tooltip(
      message: isGitRepo
          ? (hasUnpushed ? 'Has unpushed commits' : 'Git repository')
          : 'Not a git repository',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppTypography.mono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small colored tech badge for the tags row
class _TechBadge extends StatelessWidget {
  final ProjectType type;

  const _TechBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: type.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 10, color: type.color),
          const SizedBox(width: 3),
          Text(
            type.label,
            style: AppTypography.mono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: type.color,
            ),
          ),
        ],
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
