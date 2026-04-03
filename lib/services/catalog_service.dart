import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:launcher_models/launcher_models.dart';
import 'platform_helper.dart';

// SharedPreferences keys
const _kWorkspaceKey = 'catalog_workspace';
const _kCatalogKey = 'catalog_data';
const _kLastDiffKey = 'catalog_last_diff';

/// Catalog service — connects to a remote catalog server, syncs repos,
/// and manages onboarding state.
///
/// Access via the singleton [CatalogService.instance]. The instance-based
/// design keeps all mutable state encapsulated and makes the service
/// replaceable in tests.
class CatalogService {
  CatalogService._();

  /// The application-wide singleton. Replace in tests via
  /// [CatalogService.resetForTesting].
  static CatalogService instance = CatalogService._();

  /// Swap the singleton — intended for unit tests only.
  @visibleForTesting
  static void resetForTesting(CatalogService testInstance) {
    instance = testInstance;
  }

  // ── State ──

  CatalogWorkspace? _workspace;
  Catalog? _catalog;
  CatalogDiff? _lastDiff;

  /// Repos whose env templates have "ask" variables that need user input.
  /// Keyed by repo name.
  final Map<String, bool> _pendingEnvSetup = {};

  /// Current onboarding checklist for the active workspace.
  OnboardingChecklist? _onboardingChecklist;
  OnboardingChecklist? get onboardingChecklist => _onboardingChecklist;

  CatalogWorkspace? get workspace => _workspace;
  Catalog? get catalog => _catalog;
  CatalogDiff? get lastDiff => _lastDiff;
  bool get isConnected =>
      _workspace != null && _workspace!.authToken != null;

  /// Returns true when the given repo has an env template with "ask" vars
  /// that the user still needs to fill in.
  bool needsEnvSetup(String repoName) =>
      _pendingEnvSetup[repoName] ?? false;

  // ── Listeners ──

  final _listeners = <VoidCallback>[];

  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);

  void _notify() {
    for (final cb in List<VoidCallback>.from(_listeners)) {
      cb();
    }
  }

  // ── Helpers ──

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer ${_workspace!.authToken}',
        'Content-Type': 'application/json',
      };

  String get _serverUrl => _workspace!.serverUrl;

  Never _throwHttp(http.Response response, String context) {
    if (response.statusCode == 401) {
      throw Exception('Authentication expired, please reconnect');
    }
    throw Exception(
        '$context failed with status ${response.statusCode}: ${response.body}');
  }

  // ── Initialization ──

  /// Load saved workspace from SharedPreferences on app start.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final workspaceJson = prefs.getString(_kWorkspaceKey);
      if (workspaceJson != null) {
        _workspace = CatalogWorkspace.fromJson(
            jsonDecode(workspaceJson) as Map<String, dynamic>);
      }

      final catalogJson = prefs.getString(_kCatalogKey);
      if (catalogJson != null) {
        _catalog = Catalog.fromJson(
            jsonDecode(catalogJson) as Map<String, dynamic>);
      }

      final diffJson = prefs.getString(_kLastDiffKey);
      if (diffJson != null) {
        _lastDiff = CatalogDiff.fromJson(
            jsonDecode(diffJson) as Map<String, dynamic>);
      }

      await loadOnboardingState();

      debugPrint('CatalogService initialized (connected: $isConnected)');
    } catch (e) {
      debugPrint('CatalogService.initialize error: $e');
    }
  }

  // ── Join workspace ──

  /// Connect to a catalog server and authenticate via GitHub OAuth device flow.
  /// Returns the resulting [CatalogWorkspace].
  Future<CatalogWorkspace> joinWorkspace(String serverUrl) async {
    final normalizedUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    // Step 1: Fetch org info (unauthenticated)
    late http.Response infoResponse;
    try {
      infoResponse = await http
          .get(Uri.parse('$normalizedUrl/api/catalog'))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Connection to $normalizedUrl timed out');
    } on SocketException catch (e) {
      throw Exception('Cannot reach $normalizedUrl: ${e.message}');
    }

    if (infoResponse.statusCode != 200) {
      throw Exception(
          'Server returned ${infoResponse.statusCode} — is this a valid catalog server?');
    }

    final orgData = jsonDecode(infoResponse.body) as Map<String, dynamic>;
    final githubOrg = orgData['githubOrg'] as String? ??
        orgData['orgName'] as String? ??
        normalizedUrl;
    final workspaceName = orgData['name'] as String? ?? githubOrg;
    final workspaceId = const Uuid().v4();

    // Step 2: GitHub OAuth device flow
    final deviceId = const Uuid().v4();
    await PlatformHelper.openUrl(
        '$normalizedUrl/auth/github?device_id=$deviceId');
    debugPrint('CatalogService: opened browser for GitHub OAuth (device: $deviceId)');

    final token = await _pollForToken(normalizedUrl, deviceId);

    final workspace = CatalogWorkspace(
      id: workspaceId,
      name: workspaceName,
      serverUrl: normalizedUrl,
      githubOrg: githubOrg,
      authToken: token,
    );

    // Persist
    _workspace = workspace;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWorkspaceKey, jsonEncode(workspace.toJson()));

    _notify();
    debugPrint('CatalogService: joined workspace ${workspace.name}');
    return workspace;
  }

  /// Connect to a catalog server using a pre-issued API token (no OAuth).
  /// The token is set directly, then verified by fetching the catalog.
  /// Returns the resulting [CatalogWorkspace].
  Future<CatalogWorkspace> joinWithToken(
    String serverUrl,
    String token,
  ) async {
    final normalizedUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    // Step 1: Fetch org info (unauthenticated) to get workspace metadata
    late http.Response infoResponse;
    try {
      infoResponse = await http
          .get(Uri.parse('$normalizedUrl/api/catalog'))
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Connection to $normalizedUrl timed out');
    } on SocketException catch (e) {
      throw Exception('Cannot reach $normalizedUrl: ${e.message}');
    }

    if (infoResponse.statusCode != 200) {
      throw Exception(
          'Server returned ${infoResponse.statusCode} — is this a valid catalog server?');
    }

    final orgData = jsonDecode(infoResponse.body) as Map<String, dynamic>;
    final githubOrg = orgData['githubOrg'] as String? ??
        orgData['orgName'] as String? ??
        normalizedUrl;
    final workspaceName = orgData['name'] as String? ?? githubOrg;
    final workspaceId = const Uuid().v4();

    // Step 2: Create workspace with the provided token
    final workspace = CatalogWorkspace(
      id: workspaceId,
      name: workspaceName,
      serverUrl: normalizedUrl,
      githubOrg: githubOrg,
      authToken: token,
    );

    // Step 3: Persist and verify by fetching catalog
    _workspace = workspace;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWorkspaceKey, jsonEncode(workspace.toJson()));

    // Verify the token works by fetching the catalog
    try {
      await fetchCatalog();
    } catch (e) {
      // Token is invalid — rollback persisted workspace
      _workspace = null;
      await prefs.remove(_kWorkspaceKey);
      throw Exception('Token verification failed: $e');
    }

    _notify();
    debugPrint('CatalogService: joined workspace ${workspace.name} with token');
    return workspace;
  }

  /// Poll `{serverUrl}/auth/status?device_id=<id>` until a token arrives
  /// or the timeout is reached.
  Future<String> _pollForToken(
    String serverUrl,
    String deviceId, {
    Duration timeout = const Duration(minutes: 5),
    Duration interval = const Duration(seconds: 3),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      await Future.delayed(interval);
      try {
        final response = await http.get(
          Uri.parse('$serverUrl/auth/status?device_id=$deviceId'),
        );
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final token = body['token'] as String?;
          if (token != null && token.isNotEmpty) return token;
        }
      } catch (e) {
        debugPrint('CatalogService: token poll error: $e');
      }
    }
    throw Exception(
        'GitHub authentication timed out. Please try joining again.');
  }

  // ── Catalog ──

  /// Fetch the catalog from the server and cache it locally.
  Future<void> fetchCatalog() async {
    if (!isConnected) {
      throw Exception('Not connected to a catalog workspace');
    }

    late http.Response response;
    try {
      response = await http
          .get(Uri.parse('$_serverUrl/api/catalog'), headers: _authHeaders)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('Fetching catalog timed out');
    } on SocketException catch (e) {
      throw Exception('Network error while fetching catalog: ${e.message}');
    }

    if (response.statusCode != 200) _throwHttp(response, 'Fetch catalog');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _catalog = Catalog.fromJson(data);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCatalogKey, jsonEncode(_catalog!.toJson()));

    _notify();
    debugPrint('CatalogService: fetched catalog (${_catalog!.repos.length} repos)');
  }

  // ── Diff ──

  /// Compare locally known repos against the catalog and return the diff.
  Future<CatalogDiff> computeDiff() async {
    if (!isConnected) {
      throw Exception('Not connected to a catalog workspace');
    }

    // Load locally known project paths
    final projectsFile = File(
        '${PlatformHelper.dataDir}${Platform.pathSeparator}projects.json');
    final List<String> localNames = [];

    if (await projectsFile.exists()) {
      try {
        final content = await projectsFile.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        for (final item in list) {
          final path = (item as Map<String, dynamic>)['path'] as String?;
          if (path != null && path.isNotEmpty) {
            localNames.add(path.split(Platform.pathSeparator).last);
          }
        }
      } catch (e) {
        debugPrint('CatalogService.computeDiff: error reading projects.json: $e');
      }
    }

    final reposParam = localNames.join(',');
    final uri = Uri.parse('$_serverUrl/api/catalog/diff')
        .replace(queryParameters: {'repos': reposParam});

    late http.Response response;
    try {
      response = await http
          .get(uri, headers: _authHeaders)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('Computing diff timed out');
    } on SocketException catch (e) {
      throw Exception('Network error while computing diff: ${e.message}');
    }

    if (response.statusCode != 200) _throwHttp(response, 'Compute diff');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _lastDiff = CatalogDiff.fromJson(data);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastDiffKey, jsonEncode(_lastDiff!.toJson()));

    _notify();
    debugPrint('CatalogService: computed diff '
        '(${_lastDiff!.missingRepos.length} missing)');
    return _lastDiff!;
  }

  // ── Sync ──

  /// Clone a single repo into [localBasePath].
  ///
  /// After a successful clone, if the repo has an [CatalogRepo.envTemplateName],
  /// the matching template is looked up:
  /// - If any var is type `"ask"`: marks the repo as pending env setup so the
  ///   UI can show a "Setup env" button.
  /// - Otherwise: auto-applies the template immediately (no user input needed).
  Future<void> syncRepo(CatalogRepo repo, String localBasePath) async {
    final targetPath = '$localBasePath${Platform.pathSeparator}${repo.name}';

    debugPrint('CatalogService: cloning ${repo.url} → $targetPath');

    final result = await Process.run(
      'git',
      ['clone', repo.url, targetPath],
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to clone ${repo.name}: ${result.stderr}');
    }

    debugPrint('CatalogService: cloned ${repo.name} successfully');

    // Handle env template after clone
    if (repo.envTemplateName != null && _catalog != null) {
      final template = _catalog!.envTemplates.where(
        (t) => t.name == repo.envTemplateName,
      ).firstOrNull;

      if (template != null) {
        final hasAskVars = template.vars.values.any((v) => v.type == 'ask');
        if (hasAskVars) {
          // Needs user input — mark pending; UI will show "Setup env" button
          _pendingEnvSetup[repo.name] = true;
          debugPrint('CatalogService: ${repo.name} needs env setup (has "ask" vars)');
        } else {
          // All vars are default/vault — apply automatically
          try {
            await applyEnvTemplate(targetPath, template, {});
            debugPrint('CatalogService: auto-applied env template for ${repo.name}');
          } catch (e) {
            debugPrint('CatalogService: failed to auto-apply env template for ${repo.name}: $e');
          }
        }
      } else {
        debugPrint('CatalogService: env template "${repo.envTemplateName}" not found in catalog');
      }
    }

    _notify();
  }

  /// Applies an env template to a cloned repo directory.
  ///
  /// [repoPath] — absolute path to the cloned repo.
  /// [template] — the [EnvTemplate] from the catalog.
  /// [userValues] — map of varName → value for vars marked `"ask"` (must be
  ///   pre-collected by the UI before calling this method).
  ///
  /// Writes a `.env` file inside [repoPath]. If `.env` already exists the
  /// content is written to `.env.new` instead and a warning is logged.
  ///
  /// Variable handling:
  /// - `"default"`: writes `NAME=value`
  /// - `"ask"`: writes `NAME=<userValue>` (throws [ArgumentError] if missing)
  /// - `"vault"`: writes a comment `# VAULT: pull from <vaultPath>`
  Future<void> applyEnvTemplate(
    String repoPath,
    EnvTemplate template,
    Map<String, String> userValues,
  ) async {
    final lines = <String>[];
    for (final entry in template.vars.entries) {
      final name = entry.key;
      final envVar = entry.value;
      switch (envVar.type) {
        case 'default':
          lines.add('$name=${envVar.value ?? ''}');
        case 'ask':
          if (!userValues.containsKey(name)) {
            throw ArgumentError(
              'Missing required value for env var "$name" (type=ask)',
            );
          }
          lines.add('$name=${userValues[name]}');
        case 'vault':
          lines.add('# VAULT: pull from ${envVar.vaultPath ?? name}');
        default:
          // Unknown type — write a comment and skip
          lines.add('# UNKNOWN_TYPE($name): ${envVar.type}');
      }
    }

    final content = '${lines.join('\n')}\n';
    final envFile = File('$repoPath${Platform.pathSeparator}.env');
    final bool alreadyExists = await envFile.exists();

    if (alreadyExists) {
      // Do not overwrite — write to .env.new and warn
      final newFile = File('$repoPath${Platform.pathSeparator}.env.new');
      await newFile.writeAsString(content);
      debugPrint(
        'CatalogService.applyEnvTemplate: .env already exists in $repoPath — '
        'written to .env.new instead',
      );
    } else {
      await envFile.writeAsString(content);
      debugPrint(
        'CatalogService.applyEnvTemplate: wrote .env for template '
        '"${template.name}" in $repoPath',
      );
    }

    // Clear any pending flag now that setup is done
    final repoName = repoPath.split(Platform.pathSeparator).last;
    _pendingEnvSetup.remove(repoName);
    _notify();
  }

  /// Clone all repos that are in the diff's missing list.
  Future<void> syncAllMissing(String localBasePath) async {
    if (_lastDiff == null) {
      throw Exception('No diff available — call computeDiff() first');
    }

    for (final repo in _lastDiff!.missingRepos) {
      await syncRepo(repo, localBasePath);
    }

    debugPrint('CatalogService: syncAllMissing complete');
  }

  // ── Onboarding state machine ──

  String _onboardingKey() =>
      'onboarding_${_workspace?.id ?? 'default'}';

  /// Persist the current checklist to SharedPreferences.
  Future<void> _persistOnboardingState() async {
    if (_onboardingChecklist == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _onboardingKey(),
      jsonEncode(_onboardingChecklist!.toJson()),
    );
  }

  /// Load onboarding state from SharedPreferences. Called by [initialize].
  Future<void> loadOnboardingState() async {
    if (_workspace == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_onboardingKey());
      if (raw != null) {
        _onboardingChecklist = OnboardingChecklist.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        debugPrint('CatalogService: loaded onboarding state '
            '(${_onboardingChecklist!.steps.length} steps, '
            'progress: ${(_onboardingChecklist!.progress * 100).toStringAsFixed(0)}%)');
      }
    } catch (e) {
      debugPrint('CatalogService.loadOnboardingState error: $e');
    }
  }

  /// Build an [OnboardingStep] with an updated [status] (and optional [error]).
  OnboardingStep _updateStep(
    OnboardingStep step,
    OnboardingStatus status, {
    String? error,
  }) =>
      step.copyWith(status: status, error: error, clearError: error == null);

  /// Replace a step by [id] in the checklist and persist + notify.
  Future<void> _applyStepUpdate(
    String stepId,
    OnboardingStatus status, {
    String? error,
  }) async {
    if (_onboardingChecklist == null) return;
    final updated = _onboardingChecklist!.steps.map((s) {
      if (s.id == stepId) return _updateStep(s, status, error: error);
      return s;
    }).toList();
    _onboardingChecklist = _onboardingChecklist!.copyWith(steps: updated);
    await _persistOnboardingState();
    _notify();
  }

  /// Initialize a fresh [OnboardingChecklist] for the current workspace.
  ///
  /// Steps generated (in order):
  /// 1. `clone_<repoName>` — one per required repo
  /// 2. `env_<repoName>`   — one per required repo that has an env template
  /// 3. `build_verify`     — aggregate build step
  /// 4. `test_verify`      — aggregate test step
  Future<void> startOnboarding() async {
    if (_workspace == null) {
      throw Exception('Not connected to a catalog workspace');
    }
    if (_catalog == null) {
      throw Exception('Catalog not loaded — call fetchCatalog() first');
    }

    final requiredRepos =
        _catalog!.repos.where((r) => r.required).toList();

    final steps = <OnboardingStep>[
      // Clone steps
      for (final repo in requiredRepos)
        OnboardingStep(
          id: 'clone_${repo.name}',
          label: 'Clone ${repo.name}',
          status: OnboardingStatus.pending,
          repoName: repo.name,
        ),

      // Env steps (only repos with an env template)
      for (final repo in requiredRepos.where((r) => r.envTemplateName != null))
        OnboardingStep(
          id: 'env_${repo.name}',
          label: 'Setup env: ${repo.name}',
          status: OnboardingStatus.pending,
          repoName: repo.name,
        ),

      // Aggregate steps
      OnboardingStep(
        id: 'build_verify',
        label: 'Verify builds',
        status: OnboardingStatus.pending,
      ),
      OnboardingStep(
        id: 'test_verify',
        label: 'Run tests',
        status: OnboardingStatus.pending,
      ),
    ];

    _onboardingChecklist = OnboardingChecklist(
      workspaceId: _workspace!.id,
      steps: steps,
      startedAt: DateTime.now(),
    );

    await _persistOnboardingState();
    _notify();
    debugPrint('CatalogService: started onboarding with ${steps.length} steps');
  }

  /// Drive the onboarding state machine from the beginning.
  ///
  /// 1. Clone steps: clone each required repo
  /// 2. Env steps: auto-apply if no "ask" vars, else pause for UI input
  /// 3. Build verify: run `flutter pub get` or `cargo build`
  /// 4. Test verify: run `flutter test` or `cargo test`
  Future<void> runOnboarding(String localBasePath) async {
    if (_onboardingChecklist == null) {
      throw Exception('No onboarding checklist — call startOnboarding() first');
    }
    if (_catalog == null) {
      throw Exception('Catalog not loaded — call fetchCatalog() first');
    }

    final requiredRepos =
        _catalog!.repos.where((r) => r.required).toList();

    // ── 1. Clone steps ──
    for (final repo in requiredRepos) {
      final stepId = 'clone_${repo.name}';
      await _applyStepUpdate(stepId, OnboardingStatus.inProgress);
      try {
        await syncRepo(repo, localBasePath);
        await _applyStepUpdate(stepId, OnboardingStatus.done);
        debugPrint('CatalogService: clone step done for ${repo.name}');
      } catch (e) {
        await _applyStepUpdate(
          stepId,
          OnboardingStatus.failed,
          error: e.toString(),
        );
        debugPrint('CatalogService: clone step failed for ${repo.name}: $e');
      }
    }

    // ── 2. Env steps ──
    for (final repo in requiredRepos.where((r) => r.envTemplateName != null)) {
      final stepId = 'env_${repo.name}';
      final step = _onboardingChecklist!.steps
          .firstWhere((s) => s.id == stepId, orElse: () => OnboardingStep(
                id: stepId,
                label: 'Setup env: ${repo.name}',
                status: OnboardingStatus.pending,
              ));

      if (step.status == OnboardingStatus.done) continue;

      if (needsEnvSetup(repo.name)) {
        // Needs user input — mark inProgress and stop; UI must prompt
        await _applyStepUpdate(stepId, OnboardingStatus.inProgress);
        debugPrint('CatalogService: env step paused for ${repo.name} — needs user input');
        return;
      }

      // Auto-apply if all vars are default/vault
      await _applyStepUpdate(stepId, OnboardingStatus.inProgress);
      try {
        final template = _catalog!.envTemplates
            .where((t) => t.name == repo.envTemplateName)
            .firstOrNull;
        if (template != null) {
          final repoPath =
              '$localBasePath${Platform.pathSeparator}${repo.name}';
          await applyEnvTemplate(repoPath, template, {});
        }
        await _applyStepUpdate(stepId, OnboardingStatus.done);
        debugPrint('CatalogService: env step done for ${repo.name}');
      } catch (e) {
        await _applyStepUpdate(
          stepId,
          OnboardingStatus.failed,
          error: e.toString(),
        );
        debugPrint('CatalogService: env step failed for ${repo.name}: $e');
      }
    }

    // ── 3. Build verify ──
    await _applyStepUpdate('build_verify', OnboardingStatus.inProgress);
    try {
      await _runBuildVerify(localBasePath, requiredRepos);
      await _applyStepUpdate('build_verify', OnboardingStatus.done);
      debugPrint('CatalogService: build_verify done');
    } catch (e) {
      await _applyStepUpdate(
        'build_verify',
        OnboardingStatus.failed,
        error: e.toString(),
      );
      debugPrint('CatalogService: build_verify failed: $e');
    }

    // ── 4. Test verify ──
    await _applyStepUpdate('test_verify', OnboardingStatus.inProgress);
    try {
      await _runTestVerify(localBasePath, requiredRepos);
      await _applyStepUpdate('test_verify', OnboardingStatus.done);
      debugPrint('CatalogService: test_verify done');
    } catch (e) {
      await _applyStepUpdate(
        'test_verify',
        OnboardingStatus.failed,
        error: e.toString(),
      );
      debugPrint('CatalogService: test_verify failed: $e');
    }

    // Mark completion if every step is done
    if (_onboardingChecklist!.isComplete) {
      _onboardingChecklist =
          _onboardingChecklist!.copyWith(completedAt: DateTime.now());
      await _persistOnboardingState();
      _notify();
      debugPrint('CatalogService: onboarding complete!');
    }
  }

  /// Detect the dominant project type in [repoPath] and run the appropriate
  /// build command.
  Future<void> _runBuildVerify(
    String localBasePath,
    List<CatalogRepo> repos,
  ) async {
    for (final repo in repos) {
      final repoPath = '$localBasePath${Platform.pathSeparator}${repo.name}';
      final hasPubspec =
          await File('$repoPath${Platform.pathSeparator}pubspec.yaml').exists();
      final hasCargoToml =
          await File('$repoPath${Platform.pathSeparator}Cargo.toml').exists();

      if (hasPubspec) {
        final result = await Process.run(
          'flutter',
          ['pub', 'get'],
          workingDirectory: repoPath,
        );
        if (result.exitCode != 0) {
          throw Exception(
              'flutter pub get failed in ${repo.name}: ${result.stderr}');
        }
      } else if (hasCargoToml) {
        final result = await Process.run(
          'cargo',
          ['build'],
          workingDirectory: repoPath,
        );
        if (result.exitCode != 0) {
          throw Exception(
              'cargo build failed in ${repo.name}: ${result.stderr}');
        }
      }
      // If neither file exists, skip (no known build system)
    }
  }

  /// Detect the dominant project type in [repoPath] and run the appropriate
  /// test command.
  Future<void> _runTestVerify(
    String localBasePath,
    List<CatalogRepo> repos,
  ) async {
    for (final repo in repos) {
      final repoPath = '$localBasePath${Platform.pathSeparator}${repo.name}';
      final hasPubspec =
          await File('$repoPath${Platform.pathSeparator}pubspec.yaml').exists();
      final hasCargoToml =
          await File('$repoPath${Platform.pathSeparator}Cargo.toml').exists();

      if (hasPubspec) {
        final result = await Process.run(
          'flutter',
          ['test'],
          workingDirectory: repoPath,
        );
        if (result.exitCode != 0) {
          throw Exception(
              'flutter test failed in ${repo.name}: ${result.stderr}');
        }
      } else if (hasCargoToml) {
        final result = await Process.run(
          'cargo',
          ['test'],
          workingDirectory: repoPath,
        );
        if (result.exitCode != 0) {
          throw Exception(
              'cargo test failed in ${repo.name}: ${result.stderr}');
        }
      }
    }
  }

  /// Resume onboarding from the first non-done step. Already-done steps are
  /// skipped automatically.
  Future<void> resumeOnboarding(String localBasePath) async {
    if (_onboardingChecklist == null) {
      throw Exception('No onboarding checklist — call startOnboarding() first');
    }

    // Find the first step that is not done
    final firstPending = _onboardingChecklist!.steps.firstWhere(
      (s) => s.status != OnboardingStatus.done,
      orElse: () => _onboardingChecklist!.steps.last,
    );

    if (firstPending.status == OnboardingStatus.done) {
      debugPrint('CatalogService.resumeOnboarding: all steps already done');
      return;
    }

    // Reset any inProgress/failed steps back to pending so runOnboarding()
    // can re-drive them cleanly. Already-done steps are left as-is.
    final reset = _onboardingChecklist!.steps.map((s) {
      if (s.status == OnboardingStatus.inProgress ||
          s.status == OnboardingStatus.failed) {
        return s.copyWith(status: OnboardingStatus.pending, clearError: true);
      }
      return s;
    }).toList();
    _onboardingChecklist = _onboardingChecklist!.copyWith(steps: reset);
    await _persistOnboardingState();
    _notify();

    await runOnboarding(localBasePath);
  }

  /// Fetch the onboarding checklist from the server (remote state).
  Future<OnboardingChecklist?> getOnboardingState() async {
    if (!isConnected) {
      throw Exception('Not connected to a catalog workspace');
    }

    late http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$_serverUrl/api/onboarding'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Fetching onboarding state timed out');
    } on SocketException catch (e) {
      throw Exception(
          'Network error while fetching onboarding state: ${e.message}');
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      _throwHttp(response, 'Get onboarding state');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return OnboardingChecklist.fromJson(data);
  }

  // ── Disconnect ──

  /// Clear all local state and SharedPreferences keys.
  Future<void> disconnect() async {
    final onboardingKey = _workspace != null ? _onboardingKey() : null;

    _workspace = null;
    _catalog = null;
    _lastDiff = null;
    _onboardingChecklist = null;
    _pendingEnvSetup.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kWorkspaceKey);
    await prefs.remove(_kCatalogKey);
    await prefs.remove(_kLastDiffKey);
    if (onboardingKey != null) {
      await prefs.remove(onboardingKey);
    }

    _notify();
    debugPrint('CatalogService: disconnected');
  }
}
