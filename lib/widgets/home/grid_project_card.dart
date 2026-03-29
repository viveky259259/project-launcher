import 'package:flutter/material.dart';
import 'package:launcher_models/launcher_models.dart';
import 'package:launcher_theme/launcher_theme.dart';
import '../../services/project_type_detector.dart';
import '../../services/launcher_service.dart';

class GridProjectCard extends StatefulWidget {
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

  const GridProjectCard({
    super.key,
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
  State<GridProjectCard> createState() => GridProjectCardState();
}

class GridProjectCardState extends State<GridProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skin = AppSkin.maybeOf(context);
    final primary = widget.stack.primary;

    final gridRadius = skin?.radius.gridCard ?? 16.0;
    final hoverDuration =
        skin?.animations.hoverDuration ?? const Duration(milliseconds: 150);
    final iconSize = skin?.cardStyle.gridIconSize ?? 28.0;
    final iconContainerSize = skin?.cardStyle.gridIconContainerSize ?? 56.0;
    final iconRadius = skin?.cardStyle.gridIconRadius ?? 14.0;
    final skinAccent = skin?.colors.accent ?? AppColors.accent;
    final skinWarning = skin?.colors.warning ?? AppColors.warning;
    final skinSuccess = skin?.colors.success ?? AppColors.success;
    final skinError = skin?.colors.error ?? AppColors.error;
    final showBranch = skin?.cardStyle.showBranchInline ?? true;
    final showTags = skin?.cardStyle.showTags ?? true;
    final showHealth = skin?.cardStyle.showHealthDot ?? true;
    final showActions = skin?.cardStyle.showActionIcons ?? true;
    final maxTags = skin?.cardStyle.maxVisibleTags ?? 2;
    final cardPadding = skin?.spacing.md ?? 16.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: hoverDuration,
          decoration: BoxDecoration(
            color: _isHovered ? cs.surfaceContainerHighest : cs.surface,
            borderRadius: BorderRadius.circular(gridRadius),
            border: Border.all(
              color: _isHovered
                  ? cs.outline.withValues(alpha: 0.4)
                  : cs.outline.withValues(alpha: 0.12),
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Large icon
                    Container(
                      width: iconContainerSize,
                      height: iconContainerSize,
                      decoration: BoxDecoration(
                        color: primary.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(iconRadius),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: Icon(
                              primary.icon,
                              size: iconSize,
                              color: primary.color,
                            ),
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
                                  border: Border.all(
                                    color: cs.surface,
                                    width: 2,
                                  ),
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
                          widget.dateLabel.isNotEmpty
                              ? widget.dateLabel
                              : 'No commits',
                          style: AppTypography.mono(
                            fontSize: 11,
                            color: widget.dateLabel.isNotEmpty
                                ? widget.activityColor.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        if (showHealth && widget.healthScore != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: widget.healthScore! >= 80
                                  ? skinSuccess
                                  : widget.healthScore! >= 50
                                  ? skinWarning
                                  : skinError,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        if (widget.hasUncommitted)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.edit_note_rounded,
                              size: 12,
                              color: skinWarning.withValues(alpha: 0.8),
                            ),
                          ),
                        if (widget.hasUnpushed)
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Icon(
                              Icons.cloud_upload_outlined,
                              size: 11,
                              color: skinWarning.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ),
                    // Branch name
                    if (showBranch && widget.branchName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fork_right_rounded,
                            size: 10,
                            color: skinAccent.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            widget.branchName!,
                            style: AppTypography.mono(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: skinAccent.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                    // Tags
                    if (showTags && widget.project.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 3,
                        runSpacing: 2,
                        children: widget.project.tags
                            .take(maxTags)
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.onSurface.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    // Tech stack pills (show on hover)
                    if (_isHovered && widget.stack.all.length > 1) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 3,
                        children: widget.stack.all
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: t.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: t.color,
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

              // Activity badge (top center)
              if (widget.activityBadge != null)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.badgeColor?.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              widget.badgeColor?.withValues(alpha: 0.4) ??
                              Colors.transparent,
                        ),
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
                  child: Icon(Icons.star_rounded, size: 14, color: skinAccent),
                ),

              // Hover actions (bottom)
              if (showActions && _isHovered)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GridAction(
                        icon: Icons.terminal_rounded,
                        tooltip: 'Terminal',
                        onTap: widget.onOpenTerminal,
                      ),
                      const SizedBox(width: 4),
                      GridAction(
                        icon: Icons.code_rounded,
                        tooltip: 'VS Code',
                        onTap: widget.onOpenVSCode,
                      ),
                      const SizedBox(width: 4),
                      GridAction(
                        icon: Icons.folder_open_rounded,
                        tooltip: 'Finder',
                        onTap: () =>
                            LauncherService.openInFinder(widget.project.path),
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

class GridAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const GridAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

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
