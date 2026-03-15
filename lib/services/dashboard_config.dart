import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Types of tiles available for the dashboard
enum DashboardTileType {
  pinnedProjects,
  recentProjects,
  healthOverview,
  insightsSummary,
  quickActions,
  activityFeed,
  teamStatus,
  notificationsFeed,
}

/// Size of a dashboard tile
enum TileSize { small, medium, large }

/// A single tile in the dashboard layout
class DashboardTile {
  final String id;
  final DashboardTileType type;
  final TileSize size;
  final int order;
  final bool visible;

  const DashboardTile({
    required this.id,
    required this.type,
    this.size = TileSize.medium,
    required this.order,
    this.visible = true,
  });

  factory DashboardTile.fromJson(Map<String, dynamic> json) => DashboardTile(
        id: json['id'] as String,
        type: DashboardTileType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => DashboardTileType.recentProjects,
        ),
        size: TileSize.values.firstWhere(
          (s) => s.name == json['size'],
          orElse: () => TileSize.medium,
        ),
        order: json['order'] as int? ?? 0,
        visible: json['visible'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'size': size.name,
        'order': order,
        'visible': visible,
      };

  DashboardTile copyWith({TileSize? size, int? order, bool? visible}) =>
      DashboardTile(
        id: id,
        type: type,
        size: size ?? this.size,
        order: order ?? this.order,
        visible: visible ?? this.visible,
      );

  String get label {
    switch (type) {
      case DashboardTileType.pinnedProjects:
        return 'Pinned Projects';
      case DashboardTileType.recentProjects:
        return 'Recent Projects';
      case DashboardTileType.healthOverview:
        return 'Health Overview';
      case DashboardTileType.insightsSummary:
        return 'Insights';
      case DashboardTileType.quickActions:
        return 'Quick Actions';
      case DashboardTileType.activityFeed:
        return 'Activity Feed';
      case DashboardTileType.teamStatus:
        return 'Team Status';
      case DashboardTileType.notificationsFeed:
        return 'Notifications';
    }
  }

  String get description {
    switch (type) {
      case DashboardTileType.pinnedProjects:
        return 'Your pinned projects for quick access';
      case DashboardTileType.recentProjects:
        return 'Recently opened projects';
      case DashboardTileType.healthOverview:
        return 'Health scores across all projects';
      case DashboardTileType.insightsSummary:
        return 'Top AI-generated insights';
      case DashboardTileType.quickActions:
        return 'Scan, open terminal, and more';
      case DashboardTileType.activityFeed:
        return 'Recent git activity';
      case DashboardTileType.teamStatus:
        return 'Team workspace overview';
      case DashboardTileType.notificationsFeed:
        return 'Recent notification alerts';
    }
  }
}

/// Dashboard layout configuration
class DashboardConfig {
  static List<DashboardTile> _tiles = [];
  static bool _initialized = false;

  static List<DashboardTile> get tiles => List.unmodifiable(_tiles);
  static List<DashboardTile> get visibleTiles =>
      _tiles.where((t) => t.visible).toList()..sort((a, b) => a.order.compareTo(b.order));

  /// Default dashboard layout
  static final List<DashboardTile> _defaultTiles = [
    const DashboardTile(
      id: 'pinned',
      type: DashboardTileType.pinnedProjects,
      size: TileSize.large,
      order: 0,
    ),
    const DashboardTile(
      id: 'health',
      type: DashboardTileType.healthOverview,
      size: TileSize.medium,
      order: 1,
    ),
    const DashboardTile(
      id: 'insights',
      type: DashboardTileType.insightsSummary,
      size: TileSize.medium,
      order: 2,
    ),
    const DashboardTile(
      id: 'recent',
      type: DashboardTileType.recentProjects,
      size: TileSize.large,
      order: 3,
    ),
    const DashboardTile(
      id: 'actions',
      type: DashboardTileType.quickActions,
      size: TileSize.small,
      order: 4,
    ),
    const DashboardTile(
      id: 'activity',
      type: DashboardTileType.activityFeed,
      size: TileSize.medium,
      order: 5,
    ),
    const DashboardTile(
      id: 'team',
      type: DashboardTileType.teamStatus,
      size: TileSize.medium,
      order: 6,
      visible: false,
    ),
    const DashboardTile(
      id: 'notifications',
      type: DashboardTileType.notificationsFeed,
      size: TileSize.small,
      order: 7,
      visible: false,
    ),
  ];

  /// Initialize the dashboard config
  static Future<void> initialize() async {
    if (_initialized) return;
    await _load();
    _initialized = true;
  }

  /// Update a tile
  static Future<void> updateTile(DashboardTile tile) async {
    final idx = _tiles.indexWhere((t) => t.id == tile.id);
    if (idx >= 0) {
      _tiles[idx] = tile;
    }
    await _save();
  }

  /// Reorder tiles by moving tile at oldIndex to newIndex
  static Future<void> reorder(int oldIndex, int newIndex) async {
    final visible = visibleTiles;
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    if (newIndex < 0 || newIndex >= visible.length) return;

    final tile = visible[oldIndex];
    visible.removeAt(oldIndex);
    visible.insert(newIndex, tile);

    // Reassign order values
    for (var i = 0; i < visible.length; i++) {
      final idx = _tiles.indexWhere((t) => t.id == visible[i].id);
      if (idx >= 0) {
        _tiles[idx] = _tiles[idx].copyWith(order: i);
      }
    }
    await _save();
  }

  /// Toggle tile visibility
  static Future<void> toggleTile(String id, bool visible) async {
    final idx = _tiles.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _tiles[idx] = _tiles[idx].copyWith(visible: visible);
      await _save();
    }
  }

  /// Change tile size
  static Future<void> resizeTile(String id, TileSize size) async {
    final idx = _tiles.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _tiles[idx] = _tiles[idx].copyWith(size: size);
      await _save();
    }
  }

  /// Reset to default layout
  static Future<void> resetToDefault() async {
    _tiles = List.from(_defaultTiles);
    await _save();
  }

  // ── Persistence ──

  static Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('dashboardConfig');
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>;
        _tiles = list
            .map((e) => DashboardTile.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _tiles = List.from(_defaultTiles);
      }
    } catch (_) {
      _tiles = List.from(_defaultTiles);
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'dashboardConfig', jsonEncode(_tiles.map((t) => t.toJson()).toList()));
  }
}
