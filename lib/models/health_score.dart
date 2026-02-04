/// Staleness level for a project based on last activity
enum StalenessLevel {
  fresh,     // < 30 days since activity
  warning,   // 30-90 days
  stale,     // 90-180 days
  abandoned, // 180+ days
}

extension StalenessLevelExtension on StalenessLevel {
  String get label {
    switch (this) {
      case StalenessLevel.fresh:
        return 'Fresh';
      case StalenessLevel.warning:
        return 'Getting Stale';
      case StalenessLevel.stale:
        return 'Stale';
      case StalenessLevel.abandoned:
        return 'Abandoned';
    }
  }

  int get daysThreshold {
    switch (this) {
      case StalenessLevel.fresh:
        return 30;
      case StalenessLevel.warning:
        return 90;
      case StalenessLevel.stale:
        return 180;
      case StalenessLevel.abandoned:
        return 365;
    }
  }

  static StalenessLevel fromDays(int days) {
    if (days < 30) return StalenessLevel.fresh;
    if (days < 90) return StalenessLevel.warning;
    if (days < 180) return StalenessLevel.stale;
    return StalenessLevel.abandoned;
  }
}

/// Health score breakdown showing points for each category
class HealthScoreDetails {
  final int gitScore;         // Max 40 points
  final int depsScore;        // Max 30 points
  final int testsScore;       // Max 30 points

  // Git breakdown
  final bool hasRecentCommits;
  final bool noUncommittedChanges;
  final bool noUnpushedCommits;
  final DateTime? lastCommitDate;

  // Dependencies breakdown
  final bool hasDependencyFile;
  final bool hasLockFile;
  final String? dependencyFileType; // pubspec.yaml, package.json, etc.

  // Tests breakdown
  final bool hasTestFolder;
  final bool hasTestFiles;

  const HealthScoreDetails({
    required this.gitScore,
    required this.depsScore,
    required this.testsScore,
    this.hasRecentCommits = false,
    this.noUncommittedChanges = false,
    this.noUnpushedCommits = false,
    this.lastCommitDate,
    this.hasDependencyFile = false,
    this.hasLockFile = false,
    this.dependencyFileType,
    this.hasTestFolder = false,
    this.hasTestFiles = false,
  });

  int get totalScore => gitScore + depsScore + testsScore;

  HealthCategory get category {
    if (totalScore >= 80) return HealthCategory.healthy;
    if (totalScore >= 50) return HealthCategory.needsAttention;
    return HealthCategory.critical;
  }

  factory HealthScoreDetails.fromJson(Map<String, dynamic> json) {
    return HealthScoreDetails(
      gitScore: json['gitScore'] as int? ?? 0,
      depsScore: json['depsScore'] as int? ?? 0,
      testsScore: json['testsScore'] as int? ?? 0,
      hasRecentCommits: json['hasRecentCommits'] as bool? ?? false,
      noUncommittedChanges: json['noUncommittedChanges'] as bool? ?? false,
      noUnpushedCommits: json['noUnpushedCommits'] as bool? ?? false,
      lastCommitDate: json['lastCommitDate'] != null
          ? DateTime.parse(json['lastCommitDate'] as String)
          : null,
      hasDependencyFile: json['hasDependencyFile'] as bool? ?? false,
      hasLockFile: json['hasLockFile'] as bool? ?? false,
      dependencyFileType: json['dependencyFileType'] as String?,
      hasTestFolder: json['hasTestFolder'] as bool? ?? false,
      hasTestFiles: json['hasTestFiles'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gitScore': gitScore,
      'depsScore': depsScore,
      'testsScore': testsScore,
      'hasRecentCommits': hasRecentCommits,
      'noUncommittedChanges': noUncommittedChanges,
      'noUnpushedCommits': noUnpushedCommits,
      'lastCommitDate': lastCommitDate?.toIso8601String(),
      'hasDependencyFile': hasDependencyFile,
      'hasLockFile': hasLockFile,
      'dependencyFileType': dependencyFileType,
      'hasTestFolder': hasTestFolder,
      'hasTestFiles': hasTestFiles,
    };
  }
}

/// Health category based on total score
enum HealthCategory {
  healthy,        // 80-100
  needsAttention, // 50-79
  critical,       // 0-49
}

extension HealthCategoryExtension on HealthCategory {
  String get label {
    switch (this) {
      case HealthCategory.healthy:
        return 'Healthy';
      case HealthCategory.needsAttention:
        return 'Needs Attention';
      case HealthCategory.critical:
        return 'Critical';
    }
  }
}

/// Cached health data for a project
class CachedHealthScore {
  final String projectPath;
  final HealthScoreDetails details;
  final StalenessLevel staleness;
  final DateTime cachedAt;

  const CachedHealthScore({
    required this.projectPath,
    required this.details,
    required this.staleness,
    required this.cachedAt,
  });

  bool get isExpired {
    final expiry = cachedAt.add(const Duration(hours: 24));
    return DateTime.now().isAfter(expiry);
  }

  factory CachedHealthScore.fromJson(Map<String, dynamic> json) {
    return CachedHealthScore(
      projectPath: json['projectPath'] as String,
      details: HealthScoreDetails.fromJson(json['details'] as Map<String, dynamic>),
      staleness: StalenessLevel.values[json['staleness'] as int? ?? 0],
      cachedAt: DateTime.parse(json['cachedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectPath': projectPath,
      'details': details.toJson(),
      'staleness': staleness.index,
      'cachedAt': cachedAt.toIso8601String(),
    };
  }
}
