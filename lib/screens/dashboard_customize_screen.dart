import 'package:flutter/material.dart';
import '../services/dashboard_config.dart';
import '../theme/app_theme.dart';

class DashboardCustomizeScreen extends StatefulWidget {
  final VoidCallback onSaved;

  const DashboardCustomizeScreen({super.key, required this.onSaved});

  @override
  State<DashboardCustomizeScreen> createState() =>
      _DashboardCustomizeScreenState();
}

class _DashboardCustomizeScreenState extends State<DashboardCustomizeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await DashboardConfig.initialize();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Top bar
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: cs.outline.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    widget.onSaved();
                    Navigator.of(context).pop();
                  },
                  color: cs.onSurface,
                ),
                const SizedBox(width: 8),
                Text('Customize Dashboard',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await DashboardConfig.resetToDefault();
                    setState(() {});
                  },
                  child: const Text('Reset to Default'),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Expanded(
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.accent)))
          else
            Expanded(
              child: Row(
                children: [
                  // Tile list (reorderable)
                  Expanded(
                    flex: 3,
                    child: _buildTileList(cs),
                  ),
                  // Preview
                  Container(
                    width: 1,
                    color: cs.outline.withValues(alpha: 0.1),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildPreview(cs),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTileList(ColorScheme cs) {
    final allTiles = DashboardConfig.tiles.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Text(
            'Drag to reorder. Toggle visibility with the eye icon.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allTiles.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              await DashboardConfig.reorder(oldIndex, newIndex);
              setState(() {});
            },
            itemBuilder: (context, index) {
              final tile = allTiles[index];
              return _TileConfigCard(
                key: ValueKey(tile.id),
                tile: tile,
                onToggleVisibility: () async {
                  await DashboardConfig.toggleTile(tile.id, !tile.visible);
                  setState(() {});
                },
                onResize: (size) async {
                  await DashboardConfig.resizeTile(tile.id, size);
                  setState(() {});
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    final visible = DashboardConfig.visibleTiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text('Preview',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: visible.map((tile) {
              final height = switch (tile.size) {
                TileSize.small => 60.0,
                TileSize.medium => 100.0,
                TileSize.large => 150.0,
              };

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                height: height,
                decoration: BoxDecoration(
                  color: _tileColor(tile.type).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: _tileColor(tile.type).withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(_tileIcon(tile.type),
                          size: 18, color: _tileColor(tile.type)),
                      const SizedBox(width: 10),
                      Text(tile.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  color: _tileColor(tile.type),
                                  fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(tile.size.name,
                            style: AppTypography.mono(
                                fontSize: 9, color: cs.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _tileColor(DashboardTileType type) {
    switch (type) {
      case DashboardTileType.pinnedProjects:
        return AppColors.accent;
      case DashboardTileType.recentProjects:
        return const Color(0xFF8B5CF6);
      case DashboardTileType.healthOverview:
        return AppColors.success;
      case DashboardTileType.insightsSummary:
        return const Color(0xFFE879F9);
      case DashboardTileType.quickActions:
        return AppColors.warning;
      case DashboardTileType.activityFeed:
        return const Color(0xFF06B6D4);
      case DashboardTileType.teamStatus:
        return const Color(0xFF2496ED);
      case DashboardTileType.notificationsFeed:
        return AppColors.error;
    }
  }

  IconData _tileIcon(DashboardTileType type) {
    switch (type) {
      case DashboardTileType.pinnedProjects:
        return Icons.push_pin_rounded;
      case DashboardTileType.recentProjects:
        return Icons.history_rounded;
      case DashboardTileType.healthOverview:
        return Icons.favorite_rounded;
      case DashboardTileType.insightsSummary:
        return Icons.auto_awesome_rounded;
      case DashboardTileType.quickActions:
        return Icons.bolt_rounded;
      case DashboardTileType.activityFeed:
        return Icons.commit_rounded;
      case DashboardTileType.teamStatus:
        return Icons.groups_rounded;
      case DashboardTileType.notificationsFeed:
        return Icons.notifications_rounded;
    }
  }
}

class _TileConfigCard extends StatelessWidget {
  final DashboardTile tile;
  final VoidCallback onToggleVisibility;
  final ValueChanged<TileSize> onResize;

  const _TileConfigCard({
    super.key,
    required this.tile,
    required this.onToggleVisibility,
    required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _color();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tile.visible
            ? cs.surface
            : cs.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: tile.visible
              ? color.withValues(alpha: 0.2)
              : cs.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Drag handle
          Icon(Icons.drag_indicator_rounded,
              size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),

          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: tile.visible ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_icon(), size: 16, color: color),
          ),
          const SizedBox(width: 12),

          // Label & description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tile.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tile.visible
                            ? cs.onSurface
                            : cs.onSurfaceVariant)),
                Text(tile.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),

          // Size selector
          if (tile.visible) ...[
            _SizeChip(
              label: 'S',
              isActive: tile.size == TileSize.small,
              onTap: () => onResize(TileSize.small),
              color: color,
            ),
            const SizedBox(width: 4),
            _SizeChip(
              label: 'M',
              isActive: tile.size == TileSize.medium,
              onTap: () => onResize(TileSize.medium),
              color: color,
            ),
            const SizedBox(width: 4),
            _SizeChip(
              label: 'L',
              isActive: tile.size == TileSize.large,
              onTap: () => onResize(TileSize.large),
              color: color,
            ),
            const SizedBox(width: 8),
          ],

          // Visibility toggle
          IconButton(
            icon: Icon(
              tile.visible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              size: 18,
              color: tile.visible ? color : cs.onSurfaceVariant,
            ),
            onPressed: onToggleVisibility,
            tooltip: tile.visible ? 'Hide' : 'Show',
          ),
        ],
      ),
    );
  }

  Color _color() {
    switch (tile.type) {
      case DashboardTileType.pinnedProjects:
        return AppColors.accent;
      case DashboardTileType.recentProjects:
        return const Color(0xFF8B5CF6);
      case DashboardTileType.healthOverview:
        return AppColors.success;
      case DashboardTileType.insightsSummary:
        return const Color(0xFFE879F9);
      case DashboardTileType.quickActions:
        return AppColors.warning;
      case DashboardTileType.activityFeed:
        return const Color(0xFF06B6D4);
      case DashboardTileType.teamStatus:
        return const Color(0xFF2496ED);
      case DashboardTileType.notificationsFeed:
        return AppColors.error;
    }
  }

  IconData _icon() {
    switch (tile.type) {
      case DashboardTileType.pinnedProjects:
        return Icons.push_pin_rounded;
      case DashboardTileType.recentProjects:
        return Icons.history_rounded;
      case DashboardTileType.healthOverview:
        return Icons.favorite_rounded;
      case DashboardTileType.insightsSummary:
        return Icons.auto_awesome_rounded;
      case DashboardTileType.quickActions:
        return Icons.bolt_rounded;
      case DashboardTileType.activityFeed:
        return Icons.commit_rounded;
      case DashboardTileType.teamStatus:
        return Icons.groups_rounded;
      case DashboardTileType.notificationsFeed:
        return Icons.notifications_rounded;
    }
  }
}

class _SizeChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;

  const _SizeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.4)
                : cs.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Center(
          child: Text(label,
              style: AppTypography.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : cs.onSurfaceVariant,
              )),
        ),
      ),
    );
  }
}
