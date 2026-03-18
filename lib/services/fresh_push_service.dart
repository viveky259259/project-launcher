import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/project.dart';
import 'app_logger.dart';
import 'export_service.dart';

/// A single log entry emitted during push for detailed progress display.
class PushLogEntry {
  final DateTime timestamp;
  final String icon;
  final String message;
  final String? detail;

  const PushLogEntry({
    required this.timestamp,
    required this.icon,
    required this.message,
    this.detail,
  });
}

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
    void Function(PushLogEntry entry)? onLog,
  }) async {
    final tmpDir = await Directory.systemTemp.createTemp('fresh_push_');
    final workDir = tmpDir.path;
    final authUrl = _buildAuthUrl(remoteUrlTemplate, token);
    final results = <FreshPushResult>[];
    final usedNames = <String, int>{};

    void log(String icon, String message, [String? detail]) {
      onLog?.call(PushLogEntry(
        timestamp: DateTime.now(),
        icon: icon,
        message: message,
        detail: detail,
      ));
    }

    try {
      // 1. Check what's already uploaded
      onProgress?.call(
          0, projects.length, 'Checking', 'Fetching uploaded files...');
      log('🔍', 'Checking remote repository...');
      final alreadyUploaded = await fetchUploadedFiles(
        remoteUrl: remoteUrlTemplate,
        token: token,
      );
      if (alreadyUploaded.isNotEmpty) {
        log('📂', 'Found ${alreadyUploaded.length} existing files on remote');
      } else {
        log('📂', 'Remote repository is empty');
      }
      AppLogger.info(
          _tag, 'Found ${alreadyUploaded.length} files on GitHub');

      // 2. Init git repo and graft onto remote history (no file download)
      onProgress?.call(
          0, projects.length, 'Setting up', 'Initializing...');
      log('⚙️', 'Initializing local git repository...');
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

      await Process.run(
        'git', ['config', 'http.postBuffer', '524288000'],
        workingDirectory: workDir,
      );

      // Fetch remote commit+tree refs (no blob content) via --filter=blob:none.
      // We use git plumbing (ls-tree, mktree, commit-tree) to build commits
      // that extend the remote's tree without needing local blob data.
      String? parentCommitSha;
      String? parentTreeSha;
      if (alreadyUploaded.isNotEmpty) {
        log('🔗', 'Linking to remote history...');
        final fetchRes = await Process.run(
          'git', ['fetch', '--depth', '1', '--filter=blob:none', 'origin', 'main'],
          workingDirectory: workDir,
        );
        if (fetchRes.exitCode == 0) {
          final commitRes = await Process.run(
            'git', ['rev-parse', 'origin/main'],
            workingDirectory: workDir,
          );
          final treeRes = await Process.run(
            'git', ['rev-parse', 'origin/main^{tree}'],
            workingDirectory: workDir,
          );
          if (commitRes.exitCode == 0 && treeRes.exitCode == 0) {
            parentCommitSha = (commitRes.stdout as String).trim();
            parentTreeSha = (treeRes.stdout as String).trim();
            log('✅', 'Linked to remote — existing files preserved',
                '${alreadyUploaded.length} files on remote');
          }
        }
        if (parentCommitSha == null) {
          log('⚠️', 'Could not link to remote history',
              'First push will force-create branch');
        }
      }
      log('✅', 'Git repository ready');

      // 3. Push project configuration (all projects, not just selected)
      if (allProjects != null && allProjects.isNotEmpty) {
        onProgress?.call(
            0, projects.length, 'Config', 'Pushing project configuration...');
        log('📋', 'Building projects.json config...',
            '${allProjects.length} projects');

        final configMap = <String, String>{};
        for (final p in allProjects) {
          configMap[p.name] = p.path;
        }
        final configJson =
            const JsonEncoder.withIndent('  ').convert(configMap);
        final configFile =
            File('$workDir${Platform.pathSeparator}projects.json');
        await configFile.writeAsString(configJson);

        log('📤', 'Pushing projects.json...');
        final configResult = await _commitAndPush(
          workDir: workDir,
          files: ['projects.json'],
          message: 'config: update project paths (${allProjects.length} projects)',
          token: token,
          parentCommitSha: parentCommitSha,
          parentTreeSha: parentTreeSha,
          onProgress: (status) =>
              onProgress?.call(0, projects.length, 'Config', status),
        );
        parentCommitSha = configResult.commitSha;
        parentTreeSha = configResult.treeSha;
        log('✅', 'Project config pushed',
            '${allProjects.length} projects indexed');
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
          log('⏭️', 'Skipping ${projects[i].name}', 'Already on remote');
        } else {
          toUpload.add(i);
        }
      }

      final skippedCount = results.where((r) => r.skipped).length;
      if (skippedCount > 0) {
        AppLogger.info(
            _tag, 'Skipping $skippedCount already-uploaded projects');
      }

      log('📊', '${toUpload.length} to upload, $skippedCount already synced',
          '${projects.length} total selected');

      if (toUpload.isEmpty) {
        log('✅', 'All projects already synced — nothing to push');
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
          log('📦', 'Zipping ${project.name}...', project.path);
          onProgress?.call(
              idx + 1, toUpload.length, project.name, 'Zipping...');
          final zipStart = DateTime.now();
          await _zipProject(project, zipPath);

          final zipFile = File(zipPath);
          final zipSize = await zipFile.length();
          final zipDuration = DateTime.now().difference(zipStart);
          log('📦', '${project.name} zipped',
              '${_formatSize(zipSize)} in ${_formatDuration(zipDuration)}');

          if (zipSize <= _maxFileSize) {
            // Small file — push as a single zip
            onProgress?.call(
                idx + 1, toUpload.length, project.name,
                'Pushing ${_formatSize(zipSize)}...');
            log('📤', 'Pushing ${project.name}...', _formatSize(zipSize));
            final pushStart = DateTime.now();
            final pushResult = await _commitAndPush(
              workDir: workDir,
              files: [zipFileName],
              message: 'add: ${project.name}',
              token: token,
              parentCommitSha: parentCommitSha,
              parentTreeSha: parentTreeSha,
              onProgress: (status) => onProgress?.call(
                  idx + 1, toUpload.length, project.name, status),
            );
            parentCommitSha = pushResult.commitSha;
            parentTreeSha = pushResult.treeSha;

            // Delete locally
            if (await zipFile.exists()) await zipFile.delete();

            final pushDuration = DateTime.now().difference(pushStart);
            results.add(FreshPushResult(
                projectName: project.name, success: true));
            log('✅', '${project.name} pushed',
                '${_formatSize(zipSize)} in ${_formatDuration(pushDuration)}');
            AppLogger.info(_tag, 'Pushed $zipFileName (${_formatSize(zipSize)})');
          } else {
            // Large file — split into parts, push each one
            final partCount = (zipSize / _maxFileSize).ceil();
            onProgress?.call(
                idx + 1, toUpload.length, project.name,
                'Splitting into $partCount parts...');
            log('✂️', 'Splitting ${project.name}',
                '${_formatSize(zipSize)} → $partCount parts');

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
            final partPushStart = DateTime.now();
            for (var p = 0; p < partFiles.length; p++) {
              final partFile = partFiles[p];
              final partFileObj = File('$workDir${Platform.pathSeparator}$partFile');
              final partSize = await partFileObj.length();
              onProgress?.call(
                  idx + 1, toUpload.length, project.name,
                  'Pushing part ${p + 1}/${partFiles.length} (${_formatSize(partSize)})...');
              log('📤', 'Pushing ${project.name} part ${p + 1}/${partFiles.length}',
                  _formatSize(partSize));

              final partResult = await _commitAndPush(
                workDir: workDir,
                files: [partFile],
                message: 'add: ${project.name} (part ${p + 1}/${partFiles.length})',
                token: token,
                parentCommitSha: parentCommitSha,
                parentTreeSha: parentTreeSha,
                onProgress: (status) => onProgress?.call(
                    idx + 1, toUpload.length, project.name,
                    'Part ${p + 1}/${partFiles.length}: $status'),
              );
              parentCommitSha = partResult.commitSha;
              parentTreeSha = partResult.treeSha;

              // Delete part locally after push
              if (await partFileObj.exists()) await partFileObj.delete();
            }

            final totalPartDuration = DateTime.now().difference(partPushStart);
            results.add(FreshPushResult(
                projectName: project.name,
                success: true,
                parts: partFiles.length));
            log('✅', '${project.name} pushed',
                '${partFiles.length} parts, ${_formatSize(zipSize)} in ${_formatDuration(totalPartDuration)}');
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
          log('❌', 'Failed: ${project.name}',
              _sanitizeError(e.toString(), token));
          AppLogger.error(_tag, 'Failed to push ${project.name}: $e');
        }
      }

      final succeeded =
          results.where((r) => r.success && !r.skipped).length;
      final failed = results.where((r) => !r.success).length;
      log('🏁', 'Push complete',
          '$succeeded pushed, $skippedCount skipped, $failed failed');
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

  /// Commit files and push using git plumbing to avoid needing local blobs.
  ///
  /// When [parentTreeSha] is provided, uses ls-tree + mktree + commit-tree
  /// to build a new commit that extends the parent's tree with new files,
  /// without ever downloading existing file content.
  static Future<({String commitSha, String treeSha})> _commitAndPush({
    required String workDir,
    required List<String> files,
    required String message,
    String? token,
    String? parentCommitSha,
    String? parentTreeSha,
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Committing...');
    final noFetchEnv = {'GIT_NO_LAZY_FETCH': '1'};

    String newCommitSha;
    String newTreeSha;

    if (parentTreeSha != null) {
      // Plumbing mode: build tree manually to avoid needing old blobs

      // Get parent tree entries (just SHAs + paths, no blob content needed)
      final lsTreeRes = await Process.run(
        'git', ['ls-tree', parentTreeSha],
        workingDirectory: workDir,
        environment: noFetchEnv,
      );
      final existingEntries = (lsTreeRes.stdout as String).trim();

      // Hash each new file into git's object store
      final newEntries = <String>[];
      for (final f in files) {
        final hashRes = await Process.run(
          'git', ['hash-object', '-w', f],
          workingDirectory: workDir,
        );
        if (hashRes.exitCode != 0) {
          throw Exception('hash-object failed for $f: ${hashRes.stderr}');
        }
        final blobSha = (hashRes.stdout as String).trim();
        newEntries.add('100644 blob $blobSha\t$f');
      }

      // Merge parent entries with new entries (new entries override by filename)
      final newFileNames = files.toSet();
      final mergedLines = <String>[];
      if (existingEntries.isNotEmpty) {
        for (final line in existingEntries.split('\n')) {
          final parts = line.split('\t');
          if (parts.length >= 2 && !newFileNames.contains(parts.last)) {
            mergedLines.add(line);
          }
        }
      }
      mergedLines.addAll(newEntries);

      // Create new tree from merged entries (mktree reads from stdin)
      final mkTreeProc = await Process.start(
        'git', ['mktree', '--missing'],
        workingDirectory: workDir,
        environment: noFetchEnv,
      );
      mkTreeProc.stdin.writeln(mergedLines.join('\n'));
      await mkTreeProc.stdin.close();
      final mkTreeOut = await mkTreeProc.stdout.transform(const SystemEncoding().decoder).join();
      final mkTreeErr = await mkTreeProc.stderr.transform(const SystemEncoding().decoder).join();
      final mkTreeExit = await mkTreeProc.exitCode;
      if (mkTreeExit != 0) {
        throw Exception('mktree failed: $mkTreeErr');
      }
      newTreeSha = mkTreeOut.trim();

      // Create commit with parent
      final commitArgs = ['commit-tree', newTreeSha, '-m', message];
      if (parentCommitSha != null) {
        commitArgs.addAll(['-p', parentCommitSha]);
      }
      final commitTreeRes = await Process.run(
        'git', commitArgs,
        workingDirectory: workDir,
        environment: noFetchEnv,
      );
      if (commitTreeRes.exitCode != 0) {
        throw Exception('commit-tree failed: ${commitTreeRes.stderr}');
      }
      newCommitSha = (commitTreeRes.stdout as String).trim();

      // Update branch ref to point to new commit
      await Process.run(
        'git', ['update-ref', 'refs/heads/main', newCommitSha],
        workingDirectory: workDir,
      );
    } else {
      // Normal mode (empty repo) — use porcelain commands
      for (final f in files) {
        await Process.run('git', ['add', f], workingDirectory: workDir);
      }
      final commitRes = await Process.run(
        'git', ['commit', '-m', message],
        workingDirectory: workDir,
      );
      if (commitRes.exitCode != 0) {
        throw Exception('commit failed: ${commitRes.stderr}');
      }
      final shaRes = await Process.run(
        'git', ['rev-parse', 'HEAD'],
        workingDirectory: workDir,
      );
      newCommitSha = (shaRes.stdout as String).trim();
      final treeRes = await Process.run(
        'git', ['rev-parse', 'HEAD^{tree}'],
        workingDirectory: workDir,
      );
      newTreeSha = (treeRes.stdout as String).trim();
    }

    // Push
    onProgress?.call('Pushing...');
    final forcePush = parentCommitSha == null && parentTreeSha == null;
    ProcessResult pushRes;
    if (forcePush) {
      pushRes = await Process.run(
        'git', ['push', '--force', '-u', 'origin', 'main'],
        workingDirectory: workDir,
        environment: noFetchEnv,
      );
    } else {
      pushRes = await Process.run(
        'git', ['push', '--no-thin', 'origin', 'main'],
        workingDirectory: workDir,
        environment: noFetchEnv,
      );
      if (pushRes.exitCode != 0) {
        pushRes = await Process.run(
          'git', ['push', '--no-thin', '--force', '-u', 'origin', 'main'],
          workingDirectory: workDir,
          environment: noFetchEnv,
        );
      }
    }
    if (pushRes.exitCode != 0) {
      throw Exception(
          'push failed: ${_sanitizeError(pushRes.stderr as String, token)}');
    }

    return (commitSha: newCommitSha, treeSha: newTreeSha);
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

  static String _formatDuration(Duration d) {
    if (d.inSeconds < 1) return '${d.inMilliseconds}ms';
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }

  /// Strip token from error messages.
  static String _sanitizeError(String message, String? token) {
    if (token == null || token.isEmpty) return message;
    return message.replaceAll(token, '***');
  }
}
