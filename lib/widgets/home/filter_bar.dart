import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum HealthFilter { all, healthy, needsAttention, critical }
enum StalenessFilter { all, staleOnly }

class FilterBar extends StatelessWidget {
  final HealthFilter healthFilter;
  final StalenessFilter stalenessFilter;
  final String sortLabel;
  final VoidCallback onSortToggle;
  final ValueChanged<HealthFilter> onHealthFilterChanged;
  final ValueChanged<StalenessFilter> onStalenessFilterChanged;
  final int viewModeIndex;
  final ValueChanged<int> onViewModeChanged;
  final List<String> allTags;
  final String? selectedTag;
  final ValueChanged<String?> onTagChanged;

  const FilterBar({
    super.key,
    required this.healthFilter,
    required this.stalenessFilter,
    required this.sortLabel,
    required this.onSortToggle,
    required this.onHealthFilterChanged,
    required this.onStalenessFilterChanged,
    required this.viewModeIndex,
    required this.onViewModeChanged,
    this.allTags = const [],
    this.selectedTag,
    required this.onTagChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Filter pills
          _FilterPill(
            label: 'All',
            isSelected: healthFilter == HealthFilter.all && stalenessFilter == StalenessFilter.all,
            onTap: () {
              onHealthFilterChanged(HealthFilter.all);
              onStalenessFilterChanged(StalenessFilter.all);
            },
          ),
          const SizedBox(width: 6),
          _FilterPill(
            label: 'Healthy',
            isSelected: healthFilter == HealthFilter.healthy,
            onTap: () => onHealthFilterChanged(
              healthFilter == HealthFilter.healthy ? HealthFilter.all : HealthFilter.healthy,
            ),
          ),
          const SizedBox(width: 6),
          _FilterPill(
            label: 'Needs Attention',
            isSelected: healthFilter == HealthFilter.needsAttention,
            onTap: () => onHealthFilterChanged(
              healthFilter == HealthFilter.needsAttention ? HealthFilter.all : HealthFilter.needsAttention,
            ),
          ),
          const SizedBox(width: 6),
          _FilterPill(
            label: 'Stale',
            isSelected: stalenessFilter == StalenessFilter.staleOnly,
            onTap: () => onStalenessFilterChanged(
              stalenessFilter == StalenessFilter.staleOnly ? StalenessFilter.all : StalenessFilter.staleOnly,
            ),
          ),

          if (allTags.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: cs.outline.withValues(alpha: 0.2)),
            const SizedBox(width: 12),
            ...allTags.take(4).map((tag) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterPill(
                label: tag,
                isSelected: selectedTag == tag,
                onTap: () => onTagChanged(selectedTag == tag ? null : tag),
              ),
            )),
          ],

          const Spacer(),

          // Sort dropdown
          InkWell(
            onTap: onSortToggle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sort',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sortLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
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
                _ViewToggle(
                  icon: Icons.view_list_rounded,
                  isActive: viewModeIndex == 0,
                  onTap: () => onViewModeChanged(0),
                ),
                _ViewToggle(
                  icon: Icons.grid_view_rounded,
                  isActive: viewModeIndex == 1,
                  onTap: () => onViewModeChanged(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<_FilterPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.accent.withValues(alpha: 0.15)
                : _isHovered
                    ? cs.onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : cs.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSelected) ...[
                const Icon(Icons.check, size: 14, color: AppColors.accent),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: widget.isSelected ? AppColors.accent : cs.onSurfaceVariant,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? AppColors.accent : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
