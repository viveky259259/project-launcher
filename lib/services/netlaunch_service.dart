import 'dart:convert';
import 'dart:io';

import 'package:launcher_native/launcher_native.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a NetLaunch operation step.
class NetLaunchStepResult {
  final bool success;
  final String message;
  final String? error;

  const NetLaunchStepResult({
    required this.success,
    required this.message,
    this.error,
  });
}

/// Manages NetLaunch CLI detection, installation, and deployment.
class NetLaunchService {
  static const _tag = 'NetLaunch';

  /// Check if netlaunch CLI is installed globally.
  static Future<bool> isInstalled() async {
    try {
      final result = await Process.run('which', ['netlaunch']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Check if npm is available.
  static Future<bool> isNpmAvailable() async {
    try {
      final result = await Process.run('which', ['npm']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Check if npx is available (fallback for running without global install).
  static Future<bool> isNpxAvailable() async {
    try {
      final result = await Process.run('which', ['npx']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Check if the user is logged in to NetLaunch.
  static Future<bool> isLoggedIn() async {
    try {
      final result = await Process.run('netlaunch', ['whoami']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Install netlaunch CLI globally via npm.
  static Future<NetLaunchStepResult> install({
    void Function(String status)? onProgress,
  }) async {
    try {
      onProgress?.call('Checking for npm...');
      if (!await isNpmAvailable()) {
        return const NetLaunchStepResult(
          success: false,
          message: 'npm is not installed',
          error:
              'npm is required to install netlaunch. Install Node.js from https://nodejs.org',
        );
      }

      onProgress?.call('Installing netlaunch globally...');
      AppLogger.info(_tag, 'Installing netlaunch via npm install -g');

      final result = await Process.run(
        'npm',
        ['install', '-g', 'netlaunch'],
        environment: Platform.environment,
      );

      if (result.exitCode == 0) {
        AppLogger.info(_tag, 'netlaunch installed successfully');
        return const NetLaunchStepResult(
          success: true,
          message: 'netlaunch installed successfully',
        );
      }

      return NetLaunchStepResult(
        success: false,
        message: 'npm install failed (exit ${result.exitCode})',
        error: result.stderr.toString(),
      );
    } catch (e) {
      AppLogger.error(_tag, 'Install failed: $e');
      return NetLaunchStepResult(
        success: false,
        message: 'Installation failed',
        error: e.toString(),
      );
    }
  }

  /// Open browser for netlaunch login.
  static Future<NetLaunchStepResult> login({
    void Function(String status)? onProgress,
  }) async {
    try {
      onProgress?.call('Opening browser for Google login...');
      AppLogger.info(_tag, 'Starting netlaunch login');

      final result = await Process.run('netlaunch', ['login']);

      if (result.exitCode == 0) {
        AppLogger.info(_tag, 'Login successful');
        return const NetLaunchStepResult(
          success: true,
          message: 'Logged in to NetLaunch',
        );
      }

      return NetLaunchStepResult(
        success: false,
        message: 'Login failed',
        error: result.stderr.toString(),
      );
    } catch (e) {
      return NetLaunchStepResult(
        success: false,
        message: 'Login failed',
        error: e.toString(),
      );
    }
  }

  /// Deploy a directory to NetLaunch.
  static Future<NetLaunchStepResult> deploy({
    required String deployDir,
    required String siteName,
    String? apiKey,
    void Function(String status)? onProgress,
  }) async {
    try {
      // Validate directory
      onProgress?.call('Validating deploy directory...');
      final dir = Directory(deployDir);
      if (!dir.existsSync()) {
        return NetLaunchStepResult(
          success: false,
          message: 'Directory not found: $deployDir',
        );
      }

      final indexFile = File('$deployDir/index.html');
      if (!indexFile.existsSync()) {
        return const NetLaunchStepResult(
          success: false,
          message: 'No index.html found in deploy directory',
        );
      }

      // Count files for progress
      final fileCount =
          dir.listSync(recursive: true).whereType<File>().length;
      onProgress?.call('Found $fileCount files to deploy');

      // Create zip
      onProgress?.call('Creating ZIP archive...');
      final tmpZip = '${Directory.systemTemp.path}/netlaunch-deploy.zip';

      // Clean up any previous zip
      final oldZip = File(tmpZip);
      if (oldZip.existsSync()) oldZip.deleteSync();

      final zipResult = await Process.run(
        'zip',
        ['-r', tmpZip, '.', '-x', '*.DS_Store', '-x', '__MACOSX/*'],
        workingDirectory: deployDir,
      );

      if (zipResult.exitCode != 0) {
        return NetLaunchStepResult(
          success: false,
          message: 'Failed to create ZIP',
          error: zipResult.stderr.toString(),
        );
      }

      final zipFile = File(tmpZip);
      final zipSize = (zipFile.lengthSync() / 1024).toStringAsFixed(1);
      onProgress?.call('Archive created (${zipSize}KB)');

      // Determine command: global netlaunch or npx fallback
      final useGlobal = await isInstalled();
      final cmd = useGlobal ? 'netlaunch' : 'npx';
      final args = <String>[
        if (!useGlobal) ...['--yes', 'netlaunch'],
        'deploy',
        '--site',
        siteName,
        '--file',
        tmpZip,
        if (apiKey != null) ...['--key', apiKey],
      ];

      onProgress?.call('Uploading to $siteName.web.app...');
      AppLogger.info(_tag, 'Deploying to $siteName via ${useGlobal ? "netlaunch" : "npx"}');

      final deployResult = await Process.run(cmd, args);

      // Cleanup zip
      if (zipFile.existsSync()) zipFile.deleteSync();

      if (deployResult.exitCode == 0) {
        final url = 'https://$siteName.web.app';
        AppLogger.info(_tag, 'Deployed successfully to $url');
        onProgress?.call('Live at $url');
        return NetLaunchStepResult(
          success: true,
          message: url,
        );
      }

      return NetLaunchStepResult(
        success: false,
        message: 'Deploy failed (exit ${deployResult.exitCode})',
        error: deployResult.stderr.toString().isNotEmpty
            ? deployResult.stderr.toString()
            : deployResult.stdout.toString(),
      );
    } catch (e) {
      AppLogger.error(_tag, 'Deploy failed: $e');
      return NetLaunchStepResult(
        success: false,
        message: 'Deployment failed',
        error: e.toString(),
      );
    }
  }

  // ─── Deploy History ──────────────────────────────────────────────

  static const _historyKey = 'netlaunch_deploy_history';

  /// Save a deploy record.
  static Future<void> saveDeployRecord(DeployRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getDeployHistory();
    history.insert(0, record);
    // Keep last 50 entries
    if (history.length > 50) history.removeRange(50, history.length);
    final encoded = history.map((r) => r.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(encoded));
    AppLogger.info(_tag, 'Saved deploy record: ${record.url}');
  }

  /// Load all deploy history.
  static Future<List<DeployRecord>> getDeployHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => DeployRecord.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get deploy history for a specific project path.
  static Future<List<DeployRecord>> getDeployHistoryForProject(
      String projectPath) async {
    final all = await getDeployHistory();
    return all.where((r) => r.projectPath == projectPath).toList();
  }
}

/// A record of a deployment to NetLaunch.
class DeployRecord {
  final String projectPath;
  final String projectName;
  final String siteName;
  final String url;
  final String? buildCommand;
  final String? outputDir;
  final DateTime deployedAt;

  const DeployRecord({
    required this.projectPath,
    required this.projectName,
    required this.siteName,
    required this.url,
    this.buildCommand,
    this.outputDir,
    required this.deployedAt,
  });

  Map<String, dynamic> toJson() => {
        'projectPath': projectPath,
        'projectName': projectName,
        'siteName': siteName,
        'url': url,
        'buildCommand': buildCommand,
        'outputDir': outputDir,
        'deployedAt': deployedAt.toIso8601String(),
      };

  factory DeployRecord.fromJson(Map<String, dynamic> json) => DeployRecord(
        projectPath: json['projectPath'] as String? ?? '',
        projectName: json['projectName'] as String? ?? '',
        siteName: json['siteName'] as String? ?? '',
        url: json['url'] as String? ?? '',
        buildCommand: json['buildCommand'] as String?,
        outputDir: json['outputDir'] as String?,
        deployedAt: DateTime.tryParse(json['deployedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
