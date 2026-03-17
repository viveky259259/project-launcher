import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/project.dart';
import 'app_logger.dart';
import 'export_service.dart';

/// Result of a fresh-push operation for a single project.
class FreshPushResult {
  final String projectName;
  final bool success;
  final bool skipped;
  final int parts;
  final String? error;

  const FreshPushResult({
    required this.projectName,
    required this.success,
    this.skipped = false,
    this.parts = 1,
    this.error,
  });
}

/// Result of the full batch push operation.
class BatchPushResult {
  final int total;
  final int succeeded;
  final int skipped;
  final int failed;
  final List<FreshPushResult> results;

  const BatchPushResult({
    required this.total,
    required this.succeeded,
    required this.skipped,
    required this.failed,
    required this.results,
  });
}

/// Service to zip each project one at a time and push to a git remote.
///
/// Smart sync: checks GitHub for existing zips and only uploads missing ones.
/// Splits zips larger than 95MB into parts to stay under GitHub's 100MB limit.
class FreshPushService {
  static const _tag = 'FreshPush';

  /// Max file size for a single GitHub file (95MB, safe margin under 100MB limit)
  static const _maxFileSize = 95 * 1024 * 1024;

  /// Build an authenticated HTTPS remote URL using a personal access token.
  static String _buildAuthUrl(String remoteUrl, String? token) {
    if (token == null || token.isEmpty) return remoteUrl;
    if (remoteUrl.startsWith('https://')) {
      final uri = Uri.parse(remoteUrl);
      return uri.replace(userInfo: 'x-access-token:$token').toString();
    }
    return remoteUrl;
  }

  /// Extract owner/repo from a GitHub HTTPS URL.
  static (String owner, String repo)? _parseGitHubUrl(String url) {
    final cleaned = url.replaceAll('.git', '');
    final uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.host.contains('github.com')) return null;
    final segments = uri.pathSegments;
    if (segments.length < 2) return null;
    return (segments[0], segments[1]);
  }

  /// Fetch the list of files already on GitHub in the repo.
  /// Returns a set of filenames like {"project1.zip", "big_project.zip.part01"}.
  static Future<Set<String>> fetchUploadedFiles({
    required String remoteUrl,
    required String? token,
  }) async {
    final parsed = _parseGitHubUrl(remoteUrl);
    if (parsed == null) return {};

    final (owner, repo) = parsed;
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo/contents/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> contents = jsonDecode(response.body);
        return contents
            .where((f) => f['type'] == 'file')
            .map((f) => f['name'] as String)
            .toSet();
      }
    } catch (e) {
      AppLogger.warn(_tag, 'Failed to fetch repo contents: $e');
    }
    return {};
  }

  /// Check if a project is already fully uploaded.
  /// Matches either "name.zip" or "name.zip.part01" (at least part01 present).
  static bool _isAlreadyUploaded(String zipName, Set<String> uploaded) {
    // Exact match (small file, single zip)
    if (uploaded.contains(zipName)) return true;
    // Split file: check if part01 exists
    if (uploaded.contains('$zipName.part01')) return true;
    return false;
  }

  /// Zip and push projects, skipping ones already on GitHub.
  /// Splits zips > 95MB into parts for GitHub's 100MB file limit.
  /// [allProjects] — if provided, a projects.json config file is pushed
  /// containing name:path for every project (not just selected ones).
  static Future<BatchPushResult> pushProjects({
    required List<Project> projects,
    required String remoteUrlTemplate,
    String? token,
    String commitMessage = 'Initial commit — fresh export',
    List<Project>? allProjects,
    void Function(int current, int total, String projectName, String status)?
        onProgress,
  }) async {
    final tmpDir = await Directory.systemTemp.createTemp('fresh_push_');
    final workDir = tmpDir.path;
    final authUrl = _buildAuthUrl(remoteUrlTemplate, token);
    final results = <FreshPushResult>[];
    final usedNames = <String, int>{};

    try {
      // 1. Check what's already uploaded
      onProgress?.call(
          0, projects.length, 'Checking', 'Fetching uploaded files...');
      final alreadyUploaded = await fetchUploadedFiles(
        remoteUrl: remoteUrlTemplate,
        token: token,
      );
      AppLogger.info(
          _tag, 'Found ${alreadyUploaded.length} files on GitHub');

      // 2. Init fresh git repo (no clone needed — API check handles skip logic)
      onProgress?.call(
          0, projects.length, 'Setting up', 'Initializing...');
      var res = await Process.run('git', ['init'], workingDirectory: workDir);
      if (res.exitCode != 0) {
        throw Exception('git init failed: ${res.stderr}');
      }
      await Process.run(
          'git', ['branch', '-M', 'main'], workingDirectory: workDir);
      res = await Process.run(
        'git', ['remote', 'add', 'origin', authUrl],
        workingDirectory: workDir,
      );
      if (res.exitCode != 0) {
        throw Exception('git remote add failed: ${res.stderr}');
      }

      // Pull existing history if the repo has content (allows normal push)
      // If repo is empty or pull fails, first push will use --force
      bool isEmptyRepo = alreadyUploaded.isEmpty;
      if (!isEmptyRepo) {
        onProgress?.call(
            0, projects.length, 'Setting up', 'Fetching remote...');
        final pullRes = await Process.run(
          'git', ['pull', '--rebase', 'origin', 'main'],
          workingDirectory: workDir,
        );
        if (pullRes.exitCode != 0) {
          // Pull failed — treat as empty, will force push
          isEmptyRepo = true;
          AppLogger.info(_tag, 'Pull failed, will force push first commit');
        }
      }

      await Process.run(
        'git', ['config', 'http.postBuffer', '524288000'],
        workingDirectory: workDir,
      );

      // 3. Push project configuration (all projects, not just selected)
      if (allProjects != null && allProjects.isNotEmpty) {
        final configExists = alreadyUploaded.contains('projects.json');
        // Always update config — it reflects the latest state
        onProgress?.call(
            0, projects.length, 'Config', 'Pushing project configuration...');

        final configMap = <String, String>{};
        for (final p in allProjects) {
          configMap[p.name] = p.path;
        }
        final configJson =
            const JsonEncoder.withIndent('  ').convert(configMap);
        final configFile =
            File('$workDir${Platform.pathSeparator}projects.json');
        await configFile.writeAsString(configJson);

        await _commitAndPush(
          workDir: workDir,
          files: ['projects.json'],
          message: 'config: update project paths (${allProjects.length} projects)',
          token: token,
          forcePush: isEmptyRepo,
          onProgress: (status) =>
              onProgress?.call(0, projects.length, 'Config', status),
        );
        // After first push succeeds, no longer empty
        isEmptyRepo = false;
        AppLogger.info(_tag,
            'Pushed projects.json (${allProjects.length} projects)');
      }

      // 4. Build deduplicated name list and figure out which to skip
      final projectZipNames = <int, String>{};
      for (var i = 0; i < projects.length; i++) {
        var zipName = projects[i].name;
        final count = usedNames[zipName] ?? 0;
        usedNames[zipName] = count + 1;
        if (count > 0) zipName = '${zipName}_$count';
        projectZipNames[i] = '$zipName.zip';
      }

      final toUpload = <int>[];
      for (var i = 0; i < projects.length; i++) {
        if (_isAlreadyUploaded(projectZipNames[i]!, alreadyUploaded)) {
          results.add(FreshPushResult(
            projectName: projects[i].name,
            success: true,
            skipped: true,
          ));
        } else {
          toUpload.add(i);
        }
      }

      final skippedCount = results.where((r) => r.skipped).length;
      if (skippedCount > 0) {
        AppLogger.info(
            _tag, 'Skipping $skippedCount already-uploaded projects');
      }

      if (toUpload.isEmpty) {
        return BatchPushResult(
          total: projects.length,
          succeeded: 0,
          skipped: skippedCount,
          failed: 0,
          results: results,
        );
      }

      // 4. Process each pending project
      for (var idx = 0; idx < toUpload.length; idx++) {
        final i = toUpload[idx];
        final project = projects[i];
        final zipFileName = projectZipNames[i]!;
        final zipPath = '$workDir${Platform.pathSeparator}$zipFileName';

        final projectDir = Directory(project.path);
        if (!await projectDir.exists()) {
          results.add(FreshPushResult(
            projectName: project.name,
            success: false,
            error: 'Directory not found',
          ));
          continue;
        }

        try {
          // a. Zip the project
          onProgress?.call(
              idx + 1, toUpload.length, project.name, 'Zipping...');
          await _zipProject(project, zipPath);

          final zipFile = File(zipPath);
          final zipSize = await zipFile.length();

          if (zipSize <= _maxFileSize) {
            // Small file — push as a single zip
            onProgress?.call(
                idx + 1, toUpload.length, project.name, 'Committing...');
            await _commitAndPush(
              workDir: workDir,
              files: [zipFileName],
              message: 'add: ${project.name}',
              token: token,
              forcePush: isEmptyRepo && idx == 0,
              onProgress: (status) => onProgress?.call(
                  idx + 1, toUpload.length, project.name, status),
            );

            // Delete locally
            if (await zipFile.exists()) await zipFile.delete();

            results.add(FreshPushResult(
                projectName: project.name, success: true));
            AppLogger.info(_tag, 'Pushed $zipFileName (${_formatSize(zipSize)})');
          } else {
            // Large file — split into parts, push each one
            final partCount = (zipSize / _maxFileSize).ceil();
            onProgress?.call(
                idx + 1, toUpload.length, project.name,
                'Splitting into $partCount parts...');

            // Split: produces zipFileName.part01, zipFileName.part02, etc.
            final splitResult = await Process.run(
              'split',
              ['-b', '95m', '-d', '-a', '2', zipFileName, '$zipFileName.part'],
              workingDirectory: workDir,
            );
            if (splitResult.exitCode != 0) {
              throw Exception('split failed: ${splitResult.stderr}');
            }

            // Delete the original large zip immediately
            if (await zipFile.exists()) await zipFile.delete();

            // Find all part files
            final dir = Directory(workDir);
            final partFiles = await dir
                .list()
                .where((e) =>
                    e is File &&
                    e.path.contains('$zipFileName.part'))
                .map((e) => e.uri.pathSegments.last)
                .toList();
            partFiles.sort();

            // Push each part as a separate commit, delete locally after
            for (var p = 0; p < partFiles.length; p++) {
              final partFile = partFiles[p];
              onProgress?.call(
                  idx + 1, toUpload.length, project.name,
                  'Pushing part ${p + 1}/${partFiles.length}...');

              await _commitAndPush(
                workDir: workDir,
                files: [partFile],
                message: 'add: ${project.name} (part ${p + 1}/${partFiles.length})',
                token: token,
                forcePush: isEmptyRepo && idx == 0 && p == 0,
                onProgress: (status) => onProgress?.call(
                    idx + 1, toUpload.length, project.name,
                    'Part ${p + 1}/${partFiles.length}: $status'),
              );

              // Delete part locally after push
              final pf = File('$workDir${Platform.pathSeparator}$partFile');
              if (await pf.exists()) await pf.delete();
            }

            results.add(FreshPushResult(
                projectName: project.name,
                success: true,
                parts: partFiles.length));
            AppLogger.info(_tag,
                'Pushed $zipFileName in ${partFiles.length} parts (${_formatSize(zipSize)})');
          }
        } catch (e) {
          // Clean up any leftover files
          await _cleanupFiles(workDir, zipFileName);

          results.add(FreshPushResult(
            projectName: project.name,
            success: false,
            error: _sanitizeError(e.toString(), token),
          ));
          AppLogger.error(_tag, 'Failed to push ${project.name}: $e');
        }
      }

      final succeeded =
          results.where((r) => r.success && !r.skipped).length;
      final failed = results.where((r) => !r.success).length;
      AppLogger.info(_tag,
          'Done: $succeeded pushed, $skippedCount skipped, $failed failed');

      return BatchPushResult(
        total: results.length,
        succeeded: succeeded,
        skipped: skippedCount,
        failed: failed,
        results: results,
      );
    } catch (e) {
      AppLogger.error(_tag, 'Push setup failed: $e');
      return BatchPushResult(
        total: projects.length,
        succeeded: 0,
        skipped: 0,
        failed: projects.length,
        results: [
          FreshPushResult(
            projectName: 'setup',
            success: false,
            error: _sanitizeError(e.toString(), token),
          ),
        ],
      );
    } finally {
      await tmpDir.delete(recursive: true);
    }
  }

  /// Commit specific files and push to origin main.
  /// [forcePush] uses --force (for first push to empty/diverged repos).
  static Future<void> _commitAndPush({
    required String workDir,
    required List<String> files,
    required String message,
    String? token,
    bool forcePush = false,
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Committing...');
    for (final f in files) {
      await Process.run('git', ['add', f], workingDirectory: workDir);
    }
    var res = await Process.run(
      'git', ['commit', '-m', message],
      workingDirectory: workDir,
    );
    if (res.exitCode != 0) {
      throw Exception('commit failed: ${res.stderr}');
    }

    onProgress?.call('Pushing...');
    if (forcePush) {
      res = await Process.run(
        'git', ['push', '--force', '-u', 'origin', 'main'],
        workingDirectory: workDir,
      );
    } else {
      res = await Process.run(
        'git', ['push', 'origin', 'main'],
        workingDirectory: workDir,
      );
      // Fallback to force if normal push rejected
      if (res.exitCode != 0) {
        res = await Process.run(
          'git', ['push', '--force', '-u', 'origin', 'main'],
          workingDirectory: workDir,
        );
      }
    }
    if (res.exitCode != 0) {
      throw Exception(
          'push failed: ${_sanitizeError(res.stderr as String, token)}');
    }
  }

  /// Clean up zip and any part files for a project.
  static Future<void> _cleanupFiles(String workDir, String zipFileName) async {
    final dir = Directory(workDir);
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        if (name == zipFileName || name.startsWith('$zipFileName.part')) {
          await entity.delete();
        }
      }
    }
  }

  /// Zip a single project to the given output path.
  static Future<void> _zipProject(Project project, String zipPath) async {
    final excludeArgs = <String>[];
    for (final pattern in ExportService.excludePatterns) {
      excludeArgs.addAll(['-x', '*/$pattern/*', '-x', '$pattern/*']);
    }
    excludeArgs.addAll(['-x', '*/.git/*', '-x', '.git/*']);

    final result = await Process.run(
      'zip', ['-r', '-q', zipPath, '.', ...excludeArgs],
      workingDirectory: project.path,
    );

    if (result.exitCode != 0 && result.exitCode != 12) {
      throw Exception((result.stderr as String).trim());
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Strip token from error messages.
  static String _sanitizeError(String message, String? token) {
    if (token == null || token.isEmpty) return message;
    return message.replaceAll(token, '***');
  }
}
