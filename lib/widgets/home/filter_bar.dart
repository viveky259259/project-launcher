import 'package:flutter/material.dart';
import '../../screens/home_screen.dart' show SortMode;
import '../../services/project_type_detector.dart';
import 'package:launcher_theme/launcher_theme.dart';

enum HealthFilter { all, healthy, needsAttention, critical }
enum StalenessFilter { all, staleOnly }
enum ActivityFilter { all, thisWeek, lastWeek, thisMonth, lastMonth, older }
enum GitFilter { all, gitOnly, noGit, unpushed }

class FilterBar extends StatelessWidget {
  final HealthFilter healthFilter;
  final StalenessFilter stalenessFilter;
  final SortMode sortMode;
  final ValueChanged<SortMode> onSortChanged;
  final ValueChanged<HealthFilter> onHealthFilterChanged;
  final ValueChanged<StalenessFilter> onStalenessFilterChanged;
  final int viewModeIndex;
  final ValueChanged<int> onViewModeChanged;
  final List<String> allTags;
  final String? selectedTag;
  final ValueChanged<String?> onTagChanged;
  final Set<ProjectType> availableProjectTypes;
  final ProjectType? selectedProjectType;
  final ValueChanged<ProjectType?> onProjectTypeChanged;
  final ActivityFilter activityFilter;
  final ValueChanged<ActivityFilter> onActivityFilterChanged;
  final Map<ActivityFilter, int> activityCounts;
  final GitFilter gitFilter;
  final ValueChanged<GitFilter> onGitFilterChanged;
  final int unpushedCount;

  const FilterBar({
    super.key,
    required this.healthFilter,
    required this.stalenessFilter,
    required this.sortMode,
    required this.onSortChanged,
    required this.onHealthFilterChanged,
    required this.onStalenessFilterChanged,
    required this.viewModeIndex,
    required this.onViewModeChanged,
    this.allTags = const [],
    this.selectedTag,
    required this.onTagChanged,
    this.availableProjectTypes = const {},
    this.selectedProjectType,
    required this.onProjectTypeChanged,
    this.activityFilter = ActivityFilter.all,
    required this.onActivityFilterChanged,
    this.activityCounts = const {},
    this.gitFilter = GitFilter.all,
    required this.onGitFilterChanged,
    this.unpushedCount = 0,
  });

  PopupMenuEntry<SortMode> _sortMenuItem(SortMode mode, String label, IconData icon, ColorScheme cs) {
    final isSelected = sortMode == mode;
    return PopupMenuItem<SortMode>(
      value: mode,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.accent : cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.accent : cs.onSurface,
            ),
          ),
          const Spacer(),
          if (isSelected)
            Icon(Icons.check_rounded, size: 16, color: AppColors.accent),
        ],
      ),
    );
  }

  static const _activityOptions = [
    _ActivityOption(ActivityFilter.all, 'All', null),
    _ActivityOption(ActivityFilter.thisWeek, 'This Week', AppColors.success),
    _ActivityOption(ActivityFilter.lastWeek, 'Last Week', AppColors.accent),
    _ActivityOption(ActivityFilter.thisMonth, 'This Month', AppColors.warning),
    _ActivityOption(ActivityFilter.lastMonth, 'Last Month', Color(0xFFE879F9)),
    _ActivityOption(ActivityFilter.older, 'Older', Color(0xFF6B7280)),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skin = AppSkin.maybeOf(context);
    final toolbarPaddingH = skin?.spacing.toolbarPaddingH ?? 16.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Activity filters + Sort + View toggle
        Padding(
          padding: EdgeInsets.only(left: toolbarPaddingH, right: toolbarPaddingH, top: 8, bottom: 4),
          child: Row(
            children: [
              // Activity filters
              ..._activityOptions.map((opt) => Padding(
                padding: const EdgeInsets.only(right: 5),
                child: _ActivityPill(
                  label: opt.label,
                  count: activityCounts[opt.filter] ?? 0,
                  dotColor: opt.color,
                  isSelected: activityFilter == opt.filter,
                  onTap: () => onActivityFilterChanged(
                    activityFilter == opt.filter ? ActivityFilter.all : opt.filter,
                  ),
                ),
              )),

              const Spacer(),

              // Sort
              PopupMenuButton<SortMode>(
                onSelected: onSortChanged,
                offset: const Offset(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                color: cs.surface,
                itemBuilder: (_) => [
                  _sortMenuItem(SortMode.lastOpened, 'Recent', Icons.access_time_rounded, cs),
                  _sortMenuItem(SortMode.lastChanged, 'Last Changed', Icons.edit_calendar_rounded, cs),
                  _sortMenuItem(SortMode.name, 'A-Z', Icons.sort_by_alpha_rounded, cs),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Sort', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      Text(
                        switch (sortMode) { SortMode.lastOpened => 'Recent', SortMode.lastChanged => 'Changed', SortMode.name => 'A-Z' },
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // View mode toggle
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ViewToggle(icon: Icons.view_list_rounded, isActive: viewModeIndex == 0, onTap: () => onViewModeChanged(0)),
                    _ViewToggle(icon: Icons.grid_view_rounded, isActive: viewModeIndex == 1, onTap: () => onViewModeChanged(1)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Row 2: Health + Project type + Tags
        Padding(
          padding: EdgeInsets.only(left: toolbarPaddingH, right: toolbarPaddingH, bottom: 4),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterPill(
                  label: 'Healthy',
                  isSelected: healthFilter == HealthFilter.healthy,
                  onTap: () => onHealthFilterChanged(
                    healthFilter == HealthFilter.healthy ? HealthFilter.all : HealthFilter.healthy,
                  ),
                ),
                const SizedBox(width: 5),
                _FilterPill(
                  label: 'Needs Attention',
                  isSelected: healthFilter == HealthFilter.needsAttention,
                  onTap: () => onHealthFilterChanged(
                    healthFilter == HealthFilter.needsAttention ? HealthFilter.all : HealthFilter.needsAttention,
                  ),
                ),
                const SizedBox(width: 5),
                _FilterPill(
                  label: 'Stale',
                  isSelected: stalenessFilter == StalenessFilter.staleOnly,
                  onTap: () => onStalenessFilterChanged(
                    stalenessFilter == StalenessFilter.staleOnly ? StalenessFilter.all : StalenessFilter.staleOnly,
                  ),
                ),
                const SizedBox(width: 6),
                Center(child: Container(width: 1, height: 18, color: cs.outline.withValues(alpha: 0.2))),
                const SizedBox(width: 6),
                _FilterPill(
                  label: 'Git',
                  icon: Icons.check_circle_outline_rounded,
                  isSelected: gitFilter == GitFilter.gitOnly,
                  onTap: () => onGitFilterChanged(
                    gitFilter == GitFilter.gitOnly ? GitFilter.all : GitFilter.gitOnly,
                  ),
                ),
                const SizedBox(width: 5),
                _FilterPill(
                  label: 'No Git',
                  icon: Icons.cancel_outlined,
                  isSelected: gitFilter == GitFilter.noGit,
                  onTap: () => onGitFilterChanged(
                    gitFilter == GitFilter.noGit ? GitFilter.all : GitFilter.noGit,
                  ),
                ),
                const SizedBox(width: 5),
                _ActivityPill(
                  label: 'Unpushed',
                  count: unpushedCount,
                  dotColor: AppColors.warning,
                  isSelected: gitFilter == GitFilter.unpushed,
                  onTap: () => onGitFilterChanged(
                    gitFilter == GitFilter.unpushed ? GitFilter.all : GitFilter.unpushed,
                  ),
                ),

                if (availableProjectTypes.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Center(child: Container(width: 1, height: 18, color: cs.outline.withValues(alpha: 0.2))),
                  const SizedBox(width: 6),
                  ...availableProjectTypes.map((type) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _ProjectTypeChip(
                      type: type,
                      isSelected: selectedProjectType == type,
                      onTap: () => onProjectTypeChanged(selectedProjectType == type ? null : type),
                    ),
                  )),
                ],

                if (allTags.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Center(child: Container(width: 1, height: 18, color: cs.outline.withValues(alpha: 0.2))),
                  const SizedBox(width: 6),
                  ...allTags.take(4).map((tag) => Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: _FilterPill(
                      label: tag,
                      isSelected: selectedTag == tag,
                      onTap: () => onTagChanged(selectedTag == tag ? null : tag),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  State<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<_FilterPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skin = AppSkin.maybeOf(context);
    final skinAccent = skin?.colors.accent ?? AppColors.accent;
    final pillPaddingH = skin?.toolbarStyle.filterPillPaddingH ?? 14.0;
    final pillPaddingV = skin?.toolbarStyle.filterPillPaddingV ?? 7.0;
    final pillRadius = skin?.toolbarStyle.filterPillRadius ?? AppRadius.full;
    final hoverDuration = skin?.animations.hoverDuration ?? const Duration(milliseconds: 150);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: hoverDuration,
          padding: EdgeInsets.symmetric(horizontal: pillPaddingH, vertical: pillPaddingV),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? skinAccent.withValues(alpha: 0.15)
                : _isHovered
                    ? cs.onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(pillRadius),
            border: Border.all(
              color: widget.isSelected
                  ? skinAccent.withValues(alpha: 0.5)
                  : cs.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSelected) ...[
                Icon(Icons.check, size: 14, color: skinAccent),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: widget.isSelected ? skinAccent : cs.onSurfaceVariant,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewToggle({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skin = AppSkin.maybeOf(context);
    final skinAccent = skin?.colors.accent ?? AppColors.accent;
    final btnRadius = skin?.toolbarStyle.buttonRadius ?? AppRadius.sm;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(btnRadius),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? skinAccent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(btnRadius),
        ),
        child: Icon(
          icon,
          size: skin?.toolbarStyle.buttonIconSize ?? 18,
          color: isActive ? skinAccent : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ProjectTypeChip extends StatefulWidget {
  final ProjectType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProjectTypeChip({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ProjectTypeChip> createState() => _ProjectTypeChipState();
}

class _ProjectTypeChipState extends State<_ProjectTypeChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.type.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.type.label,
        waitDuration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? color.withValues(alpha: 0.2)
                  : _isHovered
                      ? color.withValues(alpha: 0.08)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: widget.isSelected
                    ? color.withValues(alpha: 0.6)
                    : _isHovered
                        ? color.withValues(alpha: 0.3)
                        : cs.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.type.icon,
                  size: 14,
                  color: widget.isSelected ? color : _isHovered ? color : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.type.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: widget.isSelected ? color : _isHovered ? color : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityOption {
  final ActivityFilter filter;
  final String label;
  final Color? color;
  const _ActivityOption(this.filter, this.label, this.color);
}

class _ActivityPill extends StatefulWidget {
  final String label;
  final int count;
  final Color? dotColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActivityPill({
    required this.label,
    required this.count,
    this.dotColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ActivityPill> createState() => _ActivityPillState();
}

class _ActivityPillState extends State<_ActivityPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = widget.dotColor ?? AppColors.accent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? activeColor.withValues(alpha: 0.15)
                : _isHovered
                    ? cs.onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: widget.isSelected
                  ? activeColor.withValues(alpha: 0.5)
                  : cs.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color dot
              if (widget.dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.isSelected ? activeColor : activeColor.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: widget.isSelected ? activeColor : cs.onSurfaceVariant,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              // Count badge
              if (widget.count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? activeColor.withValues(alpha: 0.2)
                        : cs.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: widget.isSelected ? activeColor : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
