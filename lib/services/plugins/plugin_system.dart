import 'dart:convert';
import 'dart:io';
import '../platform_helper.dart';

/// Plugin action types
enum PluginActionType { button, menuItem, statusIndicator }

/// A single action a plugin can provide
class PluginAction {
  final String id;
  final String label;
  final String? icon;
  final PluginActionType type;
  final String command;
  final List<String> args;

  const PluginAction({
    required this.id,
    required this.label,
    this.icon,
    required this.type,
    required this.command,
    this.args = const [],
  });

  factory PluginAction.fromJson(Map<String, dynamic> json) {
    return PluginAction(
      id: json['id'] as String,
      label: json['label'] as String,
      icon: json['icon'] as String?,
      type: PluginActionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => PluginActionType.button,
      ),
      command: json['command'] as String,
      args: (json['args'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'icon': icon,
    'type': type.name,
    'command': command,
    'args': args,
  };
}

/// Plugin manifest — defines what a plugin does
class PluginManifest {
  final String id;
  final String name;
  final String description;
  final String version;
  final String? author;
  final bool enabled;
  final List<PluginAction> actions;
  final Map<String, String> config;

  /// What the plugin checks for (e.g., file existence, command availability)
  final String? detectFile;
  final String? detectCommand;

  const PluginManifest({
    required this.id,
    required this.name,
    required this.description,
    this.version = '1.0.0',
    this.author,
    this.enabled = true,
    this.actions = const [],
    this.config = const {},
    this.detectFile,
    this.detectCommand,
  });

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      actions: (json['actions'] as List<dynamic>?)
              ?.map((a) => PluginAction.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      config: (json['config'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
      detectFile: json['detectFile'] as String?,
      detectCommand: json['detectCommand'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'author': author,
    'enabled': enabled,
    'actions': actions.map((a) => a.toJson()).toList(),
    'config': config,
    'detectFile': detectFile,
    'detectCommand': detectCommand,
  };

  PluginManifest copyWith({bool? enabled, Map<String, String>? config}) {
    return PluginManifest(
      id: id,
      name: name,
      description: description,
      version: version,
      author: author,
      enabled: enabled ?? this.enabled,
      actions: actions,
      config: config ?? this.config,
      detectFile: detectFile,
      detectCommand: detectCommand,
    );
  }
}

/// Result of running a plugin action
class PluginResult {
  final bool success;
  final String? output;
  final String? error;
  final Map<String, dynamic>? data;

  const PluginResult({
    required this.success,
    this.output,
    this.error,
    this.data,
  });
}

/// Plugin system — loads, manages, and executes plugins
class PluginSystem {
  static final List<PluginManifest> _plugins = [];
  static bool _initialized = false;

  static String get _pluginsDir =>
      '${PlatformHelper.dataDir}${Platform.pathSeparator}plugins';

  static String get _configFile =>
      '${PlatformHelper.dataDir}${Platform.pathSeparator}plugins_config.json';

  /// Initialize the plugin system
  static Future<void> initialize() async {
    if (_initialized) return;

    // Ensure plugins directory exists
    final dir = Directory(_pluginsDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Load built-in plugins
    _plugins.addAll(_builtInPlugins);

    // Load user plugins from plugins directory
    await _loadUserPlugins();

    // Apply saved config (enabled/disabled state)
    await _loadConfig();

    _initialized = true;
  }

  /// Get all registered plugins
  static List<PluginManifest> get plugins => List.unmodifiable(_plugins);

  /// Get enabled plugins
  static List<PluginManifest> get enabledPlugins =>
      _plugins.where((p) => p.enabled).toList();

  /// Get plugins relevant to a specific project
  static Future<List<PluginManifest>> getPluginsForProject(String projectPath) async {
    final relevant = <PluginManifest>[];
    for (final plugin in enabledPlugins) {
      if (await _isRelevant(plugin, projectPath)) {
        relevant.add(plugin);
      }
    }
    return relevant;
  }

  /// Execute a plugin action
  static Future<PluginResult> executeAction(
    PluginAction action, {
    String? projectPath,
  }) async {
    try {
      // Replace placeholders in command and args
      final cmd = _resolvePlaceholders(action.command, projectPath);
      final args = action.args
          .map((a) => _resolvePlaceholders(a, projectPath))
          .toList();

      final result = await Process.run(cmd, args,
          workingDirectory: projectPath);

      return PluginResult(
        success: result.exitCode == 0,
        output: result.stdout.toString().trim(),
        error: result.exitCode != 0
            ? result.stderr.toString().trim()
            : null,
      );
    } catch (e) {
      return PluginResult(success: false, error: e.toString());
    }
  }

  /// Toggle a plugin on/off
  static Future<void> togglePlugin(String pluginId, bool enabled) async {
    final idx = _plugins.indexWhere((p) => p.id == pluginId);
    if (idx >= 0) {
      _plugins[idx] = _plugins[idx].copyWith(enabled: enabled);
      await _saveConfig();
    }
  }

  /// Get status output for a plugin (for status indicators)
  static Future<String?> getStatusOutput(
    PluginManifest plugin,
    String projectPath,
  ) async {
    final statusActions = plugin.actions
        .where((a) => a.type == PluginActionType.statusIndicator);
    if (statusActions.isEmpty) return null;

    final result = await executeAction(statusActions.first,
        projectPath: projectPath);
    return result.success ? result.output : null;
  }

  // ── Private helpers ──

  static Future<bool> _isRelevant(PluginManifest plugin, String projectPath) async {
    if (plugin.detectFile != null) {
      final file = File('$projectPath/${plugin.detectFile}');
      return file.existsSync();
    }
    if (plugin.detectCommand != null) {
      try {
        final result = await Process.run('which', [plugin.detectCommand!]);
        return result.exitCode == 0;
      } catch (_) {
        return false;
      }
    }
    return true; // No detection criteria = always relevant
  }

  static String _resolvePlaceholders(String input, String? projectPath) {
    var result = input;
    if (projectPath != null) {
      result = result.replaceAll('{project_path}', projectPath);
      result = result.replaceAll('{project_name}',
          projectPath.split(Platform.pathSeparator).last);
    }
    result = result.replaceAll('{home}', PlatformHelper.homeDir);
    result = result.replaceAll('{data_dir}', PlatformHelper.dataDir);
    return result;
  }

  static Future<void> _loadUserPlugins() async {
    final dir = Directory(_pluginsDir);
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final plugin = PluginManifest.fromJson(json);
          // Don't add duplicates
          if (!_plugins.any((p) => p.id == plugin.id)) {
            _plugins.add(plugin);
          }
        } catch (_) {
          // Skip invalid plugin files
        }
      }
    }
  }

  static Future<void> _loadConfig() async {
    try {
      final file = File(_configFile);
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final config = jsonDecode(content) as Map<String, dynamic>;

      for (var i = 0; i < _plugins.length; i++) {
        final pluginConfig = config[_plugins[i].id];
        if (pluginConfig is Map<String, dynamic>) {
          _plugins[i] = _plugins[i].copyWith(
            enabled: pluginConfig['enabled'] as bool? ?? true,
          );
        }
      }
    } catch (_) {}
  }

  static Future<void> _saveConfig() async {
    try {
      final config = <String, dynamic>{};
      for (final plugin in _plugins) {
        config[plugin.id] = {'enabled': plugin.enabled};
      }
      final file = File(_configFile);
      await file.writeAsString(jsonEncode(config));
    } catch (_) {}
  }

  // ── Built-in Plugins ──

  static final List<PluginManifest> _builtInPlugins = [
    // Docker Status
    const PluginManifest(
      id: 'builtin.docker',
      name: 'Docker',
      description: 'Show Docker container status for projects with docker-compose',
      author: 'Project Launcher',
      detectFile: 'docker-compose.yml',
      actions: [
        PluginAction(
          id: 'docker.status',
          label: 'Container Status',
          icon: 'container',
          type: PluginActionType.statusIndicator,
          command: 'docker',
          args: ['compose', 'ps', '--format', 'json'],
        ),
        PluginAction(
          id: 'docker.up',
          label: 'Start Containers',
          icon: 'play',
          type: PluginActionType.button,
          command: 'docker',
          args: ['compose', 'up', '-d'],
        ),
        PluginAction(
          id: 'docker.down',
          label: 'Stop Containers',
          icon: 'stop',
          type: PluginActionType.button,
          command: 'docker',
          args: ['compose', 'down'],
        ),
      ],
    ),

    // GitHub CLI
    const PluginManifest(
      id: 'builtin.github',
      name: 'GitHub',
      description: 'View open issues and PRs using GitHub CLI',
      author: 'Project Launcher',
      detectFile: '.git',
      detectCommand: 'gh',
      actions: [
        PluginAction(
          id: 'github.issues',
          label: 'Open Issues',
          icon: 'issue',
          type: PluginActionType.statusIndicator,
          command: 'gh',
          args: ['issue', 'list', '--limit', '5', '--json', 'title,number,state'],
        ),
        PluginAction(
          id: 'github.prs',
          label: 'Open PRs',
          icon: 'pr',
          type: PluginActionType.button,
          command: 'gh',
          args: ['pr', 'list', '--limit', '5', '--json', 'title,number,state'],
        ),
        PluginAction(
          id: 'github.open',
          label: 'Open on GitHub',
          icon: 'browser',
          type: PluginActionType.button,
          command: 'gh',
          args: ['browse'],
        ),
      ],
    ),

    // CI/CD Status (GitHub Actions)
    const PluginManifest(
      id: 'builtin.ci',
      name: 'CI/CD Status',
      description: 'Check latest CI run status via GitHub Actions',
      author: 'Project Launcher',
      detectFile: '.github/workflows',
      detectCommand: 'gh',
      actions: [
        PluginAction(
          id: 'ci.status',
          label: 'Last Run',
          icon: 'ci',
          type: PluginActionType.statusIndicator,
          command: 'gh',
          args: ['run', 'list', '--limit', '1', '--json', 'status,conclusion,name'],
        ),
        PluginAction(
          id: 'ci.view',
          label: 'View Runs',
          icon: 'browser',
          type: PluginActionType.button,
          command: 'gh',
          args: ['run', 'list', '--limit', '5'],
        ),
      ],
    ),

    // NPM Scripts
    const PluginManifest(
      id: 'builtin.npm',
      name: 'NPM Scripts',
      description: 'Quick access to package.json scripts',
      author: 'Project Launcher',
      detectFile: 'package.json',
      actions: [
        PluginAction(
          id: 'npm.dev',
          label: 'npm run dev',
          icon: 'play',
          type: PluginActionType.button,
          command: 'npm',
          args: ['run', 'dev'],
        ),
        PluginAction(
          id: 'npm.build',
          label: 'npm run build',
          icon: 'build',
          type: PluginActionType.button,
          command: 'npm',
          args: ['run', 'build'],
        ),
        PluginAction(
          id: 'npm.test',
          label: 'npm test',
          icon: 'test',
          type: PluginActionType.button,
          command: 'npm',
          args: ['test'],
        ),
      ],
    ),

    // Flutter
    const PluginManifest(
      id: 'builtin.flutter',
      name: 'Flutter',
      description: 'Quick Flutter commands for Dart/Flutter projects',
      author: 'Project Launcher',
      detectFile: 'pubspec.yaml',
      actions: [
        PluginAction(
          id: 'flutter.run',
          label: 'flutter run',
          icon: 'play',
          type: PluginActionType.button,
          command: 'flutter',
          args: ['run'],
        ),
        PluginAction(
          id: 'flutter.test',
          label: 'flutter test',
          icon: 'test',
          type: PluginActionType.button,
          command: 'flutter',
          args: ['test'],
        ),
        PluginAction(
          id: 'flutter.analyze',
          label: 'flutter analyze',
          icon: 'analyze',
          type: PluginActionType.button,
          command: 'flutter',
          args: ['analyze'],
        ),
      ],
    ),
  ];
}
