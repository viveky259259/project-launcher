/// Parsed version info for a project.
class ReleaseInfo {
  final String? version;
  final String? lastTag;
  final int unreleasedCommits;
  final String? versionSource; // e.g., "pubspec.yaml", "package.json"
  final bool isDeployable; // true if this project is an app/service (not a library)
  final List<String> deployTargets; // e.g., ["iOS", "Android", "Web", "Docker"]

  ReleaseInfo({
    this.version,
    this.lastTag,
    this.unreleasedCommits = 0,
    this.versionSource,
    this.isDeployable = false,
    this.deployTargets = const [],
  });
}

/// Release readiness score with per-category breakdown.
class ReadinessScore {
  final int total; // 0-100
  final int gitScore; // 0-20
  final int versionScore; // 0-15
  final int testsScore; // 0-15
  final int cicdScore; // 0-15
  final int depsScore; // 0-10
  final int complianceScore; // 0-15
  final int signingScore; // 0-10
  final List<ReadinessItem> items;

  ReadinessScore({
    required this.total,
    this.gitScore = 0,
    this.versionScore = 0,
    this.testsScore = 0,
    this.cicdScore = 0,
    this.depsScore = 0,
    this.complianceScore = 0,
    this.signingScore = 0,
    this.items = const [],
  });
}

class ReadinessItem {
  final String category;
  final String label;
  final bool passed;
  final int points;
  final int maxPoints;
  final String? detail;

  ReadinessItem({
    required this.category,
    required this.label,
    required this.passed,
    required this.points,
    required this.maxPoints,
    this.detail,
  });
}

/// A single compliance check result.
class ComplianceItem {
  final String id;
  final String category; // license, secrets, sbom, signing, docs
  final String title;
  final ComplianceStatus status;
  final String? detail;
  final int weight;

  ComplianceItem({
    required this.id,
    required this.category,
    required this.title,
    required this.status,
    this.detail,
    this.weight = 10,
  });
}

enum ComplianceStatus { pass, warn, fail, skip }

/// Full compliance audit report.
class ComplianceReport {
  final List<ComplianceItem> items;
  final int score; // 0-100
  final String? licenseType;
  final List<SBOMEntry> sbom;
  final List<SecretFinding> secrets;
  final DateTime auditedAt;

  ComplianceReport({
    required this.items,
    required this.score,
    this.licenseType,
    this.sbom = const [],
    this.secrets = const [],
    required this.auditedAt,
  });
}

/// Software Bill of Materials entry.
class SBOMEntry {
  final String name;
  final String? version;
  final String? license;
  final String source; // "pubspec.lock", "package-lock.json", etc.

  SBOMEntry({
    required this.name,
    this.version,
    this.license,
    required this.source,
  });
}

/// A potential secret found in source code.
class SecretFinding {
  final String file;
  final int line;
  final String pattern; // which pattern matched
  final String snippet; // redacted snippet

  SecretFinding({
    required this.file,
    required this.line,
    required this.pattern,
    required this.snippet,
  });
}

/// Detected CI/CD and deployment configuration.
class DeploymentConfig {
  final String? ciProvider; // "GitHub Actions", "GitLab CI", "CircleCI", etc.
  final String? ciConfigPath;
  final List<String> buildTools; // "make", "fastlane", "gradle", "cargo"
  final List<String> containerFiles; // "Dockerfile", "docker-compose.yml"
  final bool hasCodeSigning;
  final String? signingDetail;

  DeploymentConfig({
    this.ciProvider,
    this.ciConfigPath,
    this.buildTools = const [],
    this.containerFiles = const [],
    this.hasCodeSigning = false,
    this.signingDetail,
  });
}
