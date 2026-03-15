/// How a checklist item is determined.
enum CheckMode {
  auto,   // Detected automatically from files/git/config
  manual, // User toggles manually
  ai,     // Claude AI analyzes and provides verdict
}

/// Status of a checklist item.
enum CheckStatus {
  pass,       // Requirement met
  fail,       // Requirement not met
  warn,       // Partially met / needs attention
  skip,       // Not applicable for this project
  pending,    // Not checked yet (manual items)
  running,    // Currently being evaluated (AI items)
}

/// A single item in the ship readiness checklist.
class ShipCheckItem {
  final String id;
  final String category;
  final String title;
  final String? description;
  final CheckMode mode;
  CheckStatus status;
  String? detail;
  final int weight; // Contribution to category score

  ShipCheckItem({
    required this.id,
    required this.category,
    required this.title,
    this.description,
    required this.mode,
    this.status = CheckStatus.pending,
    this.detail,
    this.weight = 10,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.name,
    'detail': detail,
  };

  void applyManual(Map<String, dynamic> saved) {
    if (mode == CheckMode.manual && saved['id'] == id) {
      final s = saved['status'] as String?;
      if (s != null) {
        status = CheckStatus.values.firstWhere((e) => e.name == s, orElse: () => CheckStatus.pending);
      }
      detail = saved['detail'] as String? ?? detail;
    }
  }
}

/// A category grouping multiple check items.
class ShipCategory {
  final String id;
  final String title;
  final String icon; // Material icon name for display
  final List<ShipCheckItem> items;

  ShipCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.items,
  });

  int get score {
    var totalWeight = 0;
    var earned = 0;
    for (final item in items) {
      if (item.status == CheckStatus.skip) continue;
      totalWeight += item.weight;
      if (item.status == CheckStatus.pass) {
        earned += item.weight;
      } else if (item.status == CheckStatus.warn) {
        earned += (item.weight * 0.5).round();
      }
    }
    return totalWeight > 0 ? (earned * 100 / totalWeight).round() : 100;
  }

  int get passCount => items.where((i) => i.status == CheckStatus.pass).length;
  int get failCount => items.where((i) => i.status == CheckStatus.fail).length;
  int get applicableCount => items.where((i) => i.status != CheckStatus.skip).length;
}

/// Full ship readiness report.
class ShipReadiness {
  final List<ShipCategory> categories;
  final DateTime checkedAt;

  ShipReadiness({required this.categories, required this.checkedAt});

  int get overallScore {
    if (categories.isEmpty) return 0;
    var total = 0;
    var count = 0;
    for (final cat in categories) {
      if (cat.applicableCount > 0) {
        total += cat.score;
        count++;
      }
    }
    return count > 0 ? (total / count).round() : 0;
  }

  int get totalPass => categories.fold(0, (s, c) => s + c.passCount);
  int get totalFail => categories.fold(0, (s, c) => s + c.failCount);
  int get totalItems => categories.fold(0, (s, c) => s + c.applicableCount);

  List<ShipCheckItem> get criticalFailures =>
      categories.expand((c) => c.items).where((i) => i.status == CheckStatus.fail && i.weight >= 15).toList();
}
