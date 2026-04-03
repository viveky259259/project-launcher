/// Catalog models for the Project Launcher onboarding and workspace sync features.

// ---------------------------------------------------------------------------
// CatalogRepo
// ---------------------------------------------------------------------------

/// A repo entry defined in the remote catalog.
class CatalogRepo {
  final String name;
  final String url;
  final bool required;
  final List<String> tags;
  final String? envTemplateName; // references EnvTemplate.name

  CatalogRepo({
    required this.name,
    required this.url,
    this.required = false,
    this.tags = const [],
    this.envTemplateName,
  });

  factory CatalogRepo.fromJson(Map<String, dynamic> json) {
    return CatalogRepo(
      name: json['name'] as String,
      url: json['url'] as String,
      required: json['required'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      envTemplateName: json['envTemplateName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'required': required,
      'tags': tags,
      'envTemplateName': envTemplateName,
    };
  }

  CatalogRepo copyWith({
    String? url,
    bool? required,
    List<String>? tags,
    String? envTemplateName,
    bool clearEnvTemplateName = false,
  }) {
    return CatalogRepo(
      name: name,
      url: url ?? this.url,
      required: required ?? this.required,
      tags: tags ?? this.tags,
      envTemplateName:
          clearEnvTemplateName ? null : (envTemplateName ?? this.envTemplateName),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogRepo &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

// ---------------------------------------------------------------------------
// EnvVar
// ---------------------------------------------------------------------------

/// A variable entry in an env template.
///
/// [type] is one of: `"default"`, `"ask"`, `"vault"`.
class EnvVar {
  final String type; // "default", "ask", "vault"
  final String? value; // for type=default
  final String? vaultPath; // for type=vault

  EnvVar({
    required this.type,
    this.value,
    this.vaultPath,
  });

  factory EnvVar.fromJson(Map<String, dynamic> json) {
    return EnvVar(
      type: json['type'] as String,
      value: json['value'] as String?,
      vaultPath: json['vaultPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
      'vaultPath': vaultPath,
    };
  }

  EnvVar copyWith({
    String? type,
    String? value,
    String? vaultPath,
    bool clearValue = false,
    bool clearVaultPath = false,
  }) {
    return EnvVar(
      type: type ?? this.type,
      value: clearValue ? null : (value ?? this.value),
      vaultPath: clearVaultPath ? null : (vaultPath ?? this.vaultPath),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvVar &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          value == other.value &&
          vaultPath == other.vaultPath;

  @override
  int get hashCode => Object.hash(type, value, vaultPath);
}

// ---------------------------------------------------------------------------
// EnvTemplate
// ---------------------------------------------------------------------------

/// An env template definition referenced by catalog repos.
class EnvTemplate {
  final String name;
  final Map<String, EnvVar> vars;

  EnvTemplate({
    required this.name,
    this.vars = const {},
  });

  factory EnvTemplate.fromJson(Map<String, dynamic> json) {
    final rawVars = json['vars'] as Map<String, dynamic>? ?? {};
    return EnvTemplate(
      name: json['name'] as String,
      vars: rawVars.map(
        (key, value) => MapEntry(
          key,
          EnvVar.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'vars': vars.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  EnvTemplate copyWith({
    Map<String, EnvVar>? vars,
  }) {
    return EnvTemplate(
      name: name,
      vars: vars ?? this.vars,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvTemplate &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

/// The full catalog fetched from the remote server.
class Catalog {
  final String version;
  final String githubOrg;
  final List<String> adminTeams;
  final List<CatalogRepo> repos;
  final List<EnvTemplate> envTemplates;
  final DateTime? fetchedAt;

  Catalog({
    required this.version,
    required this.githubOrg,
    this.adminTeams = const [],
    this.repos = const [],
    this.envTemplates = const [],
    this.fetchedAt,
  });

  factory Catalog.fromJson(Map<String, dynamic> json) {
    return Catalog(
      version: json['version'] as String,
      githubOrg: json['githubOrg'] as String,
      adminTeams:
          (json['adminTeams'] as List<dynamic>?)?.cast<String>() ?? [],
      repos: (json['repos'] as List<dynamic>?)
              ?.map((e) => CatalogRepo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      envTemplates: (json['envTemplates'] as List<dynamic>?)
              ?.map((e) => EnvTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      fetchedAt: json['fetchedAt'] != null
          ? DateTime.parse(json['fetchedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'githubOrg': githubOrg,
      'adminTeams': adminTeams,
      'repos': repos.map((r) => r.toJson()).toList(),
      'envTemplates': envTemplates.map((t) => t.toJson()).toList(),
      'fetchedAt': fetchedAt?.toIso8601String(),
    };
  }

  Catalog copyWith({
    String? version,
    String? githubOrg,
    List<String>? adminTeams,
    List<CatalogRepo>? repos,
    List<EnvTemplate>? envTemplates,
    DateTime? fetchedAt,
    bool clearFetchedAt = false,
  }) {
    return Catalog(
      version: version ?? this.version,
      githubOrg: githubOrg ?? this.githubOrg,
      adminTeams: adminTeams ?? this.adminTeams,
      repos: repos ?? this.repos,
      envTemplates: envTemplates ?? this.envTemplates,
      fetchedAt: clearFetchedAt ? null : (fetchedAt ?? this.fetchedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Catalog &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          githubOrg == other.githubOrg;

  @override
  int get hashCode => Object.hash(version, githubOrg);
}

// ---------------------------------------------------------------------------
// CatalogDiff
// ---------------------------------------------------------------------------

/// Result of comparing local repos against the remote catalog.
class CatalogDiff {
  final List<CatalogRepo> missingRepos; // in catalog but not cloned locally
  final List<String> extraRepos; // cloned locally but not in catalog
  final List<CatalogRepo> syncedRepos; // in catalog AND cloned locally
  final DateTime computedAt;

  CatalogDiff({
    this.missingRepos = const [],
    this.extraRepos = const [],
    this.syncedRepos = const [],
    required this.computedAt,
  });

  factory CatalogDiff.fromJson(Map<String, dynamic> json) {
    return CatalogDiff(
      missingRepos: (json['missingRepos'] as List<dynamic>?)
              ?.map((e) => CatalogRepo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      extraRepos:
          (json['extraRepos'] as List<dynamic>?)?.cast<String>() ?? [],
      syncedRepos: (json['syncedRepos'] as List<dynamic>?)
              ?.map((e) => CatalogRepo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      computedAt: DateTime.parse(json['computedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'missingRepos': missingRepos.map((r) => r.toJson()).toList(),
      'extraRepos': extraRepos,
      'syncedRepos': syncedRepos.map((r) => r.toJson()).toList(),
      'computedAt': computedAt.toIso8601String(),
    };
  }

  CatalogDiff copyWith({
    List<CatalogRepo>? missingRepos,
    List<String>? extraRepos,
    List<CatalogRepo>? syncedRepos,
    DateTime? computedAt,
  }) {
    return CatalogDiff(
      missingRepos: missingRepos ?? this.missingRepos,
      extraRepos: extraRepos ?? this.extraRepos,
      syncedRepos: syncedRepos ?? this.syncedRepos,
      computedAt: computedAt ?? this.computedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogDiff &&
          runtimeType == other.runtimeType &&
          computedAt == other.computedAt;

  @override
  int get hashCode => computedAt.hashCode;
}

// ---------------------------------------------------------------------------
// OnboardingStatus
// ---------------------------------------------------------------------------

/// Status of a single onboarding step.
enum OnboardingStatus { pending, inProgress, done, failed }

// ---------------------------------------------------------------------------
// OnboardingStep
// ---------------------------------------------------------------------------

/// A single step in the onboarding checklist.
class OnboardingStep {
  final String id; // "clone", "env", "build", "test"
  final String label; // human-readable
  final OnboardingStatus status;
  final String? repoName; // if step is repo-specific
  final String? error; // if failed

  OnboardingStep({
    required this.id,
    required this.label,
    this.status = OnboardingStatus.pending,
    this.repoName,
    this.error,
  });

  factory OnboardingStep.fromJson(Map<String, dynamic> json) {
    return OnboardingStep(
      id: json['id'] as String,
      label: json['label'] as String,
      status: OnboardingStatus.values.firstWhere(
        (e) => e.name == json['status'] as String?,
        orElse: () => OnboardingStatus.pending,
      ),
      repoName: json['repoName'] as String?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'status': status.name,
      'repoName': repoName,
      'error': error,
    };
  }

  OnboardingStep copyWith({
    String? label,
    OnboardingStatus? status,
    String? repoName,
    String? error,
    bool clearRepoName = false,
    bool clearError = false,
  }) {
    return OnboardingStep(
      id: id,
      label: label ?? this.label,
      status: status ?? this.status,
      repoName: clearRepoName ? null : (repoName ?? this.repoName),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingStep &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          repoName == other.repoName;

  @override
  int get hashCode => Object.hash(id, repoName);
}

// ---------------------------------------------------------------------------
// OnboardingChecklist
// ---------------------------------------------------------------------------

/// Full onboarding checklist state for a workspace.
class OnboardingChecklist {
  final String workspaceId;
  final List<OnboardingStep> steps;
  final DateTime startedAt;
  final DateTime? completedAt;

  OnboardingChecklist({
    required this.workspaceId,
    this.steps = const [],
    required this.startedAt,
    this.completedAt,
  });

  /// Fraction of steps that are done (0.0–1.0).
  double get progress => steps.isEmpty
      ? 0
      : steps.where((s) => s.status == OnboardingStatus.done).length /
          steps.length;

  /// True when every step has status [OnboardingStatus.done].
  bool get isComplete =>
      steps.isNotEmpty && steps.every((s) => s.status == OnboardingStatus.done);

  factory OnboardingChecklist.fromJson(Map<String, dynamic> json) {
    return OnboardingChecklist(
      workspaceId: json['workspaceId'] as String,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => OnboardingStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workspaceId': workspaceId,
      'steps': steps.map((s) => s.toJson()).toList(),
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  OnboardingChecklist copyWith({
    List<OnboardingStep>? steps,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return OnboardingChecklist(
      workspaceId: workspaceId,
      steps: steps ?? this.steps,
      startedAt: startedAt,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingChecklist &&
          runtimeType == other.runtimeType &&
          workspaceId == other.workspaceId;

  @override
  int get hashCode => workspaceId.hashCode;
}

// ---------------------------------------------------------------------------
// CatalogWorkspace
// ---------------------------------------------------------------------------

/// Connected workspace configuration stored locally.
class CatalogWorkspace {
  final String id;
  final String name;
  final String serverUrl;
  final String githubOrg;
  final String? authToken; // JWT from server
  final DateTime? lastSyncAt;

  CatalogWorkspace({
    required this.id,
    required this.name,
    required this.serverUrl,
    required this.githubOrg,
    this.authToken,
    this.lastSyncAt,
  });

  factory CatalogWorkspace.fromJson(Map<String, dynamic> json) {
    return CatalogWorkspace(
      id: json['id'] as String,
      name: json['name'] as String,
      serverUrl: json['serverUrl'] as String,
      githubOrg: json['githubOrg'] as String,
      authToken: json['authToken'] as String?,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'serverUrl': serverUrl,
      'githubOrg': githubOrg,
      'authToken': authToken,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
    };
  }

  CatalogWorkspace copyWith({
    String? name,
    String? serverUrl,
    String? githubOrg,
    String? authToken,
    DateTime? lastSyncAt,
    bool clearAuthToken = false,
    bool clearLastSyncAt = false,
  }) {
    return CatalogWorkspace(
      id: id,
      name: name ?? this.name,
      serverUrl: serverUrl ?? this.serverUrl,
      githubOrg: githubOrg ?? this.githubOrg,
      authToken: clearAuthToken ? null : (authToken ?? this.authToken),
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogWorkspace &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
