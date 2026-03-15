import 'dart:io';
import 'app_logger.dart';
import 'native_lib.dart';

/// Git service with Rust FFI acceleration (falls back to shell commands)
class GitService {
  static const _tag = 'Git';
  static bool? _useNative;

  /// Check if native library is available (cached)
  static bool get _canUseNative {
    if (_useNative == null) {
      _useNative = NativeLib.isAvailable;
      AppLogger.info(_tag, 'FFI native lib: ${_useNative! ? "available" : "not found, using Dart fallbacks"}');
    }
    return _useNative!;
  }

  /// Get the date of the last commit in a repository
  static Future<DateTime?> getLastCommitDate(String repoPath) async {
    if (_canUseNative) {
      return NativeLib.instance.getLastCommitDate(repoPath);
    }
    return _getLastCommitDateDart(repoPath);
  }

  /// Get the number of commits in a repository, optionally within a date range and by author
  static Future<int> getCommitCount(String repoPath, {DateTime? since, DateTime? until, String? author}) async {
    if (until != null || author != null) {
      // Native doesn't support until/author filtering, use Dart fallback
      return _getCommitCountDart(repoPath, since: since, until: until, author: author);
    }
    if (_canUseNative) {
      return NativeLib.instance.getCommitCount(repoPath, since: since);
    }
    return _getCommitCountDart(repoPath, since: since);
  }

  /// Check if there are uncommitted changes (modified, staged, or untracked files)
  static Future<bool> hasUncommittedChanges(String repoPath) async {
    if (_canUseNative) {
      return NativeLib.instance.hasUncommittedChanges(repoPath);
    }
    return _hasUncommittedChangesDart(repoPath);
  }

  /// Get the number of commits that haven't been pushed to the remote
  static Future<int> getUnpushedCommitCount(String repoPath) async {
    if (_canUseNative) {
      return NativeLib.instance.getUnpushedCommitCount(repoPath);
    }
    return _getUnpushedCommitCountDart(repoPath);
  }

  /// Check if a directory is a git repository
  static Future<bool> isGitRepository(String path) async {
    if (_canUseNative) {
      return NativeLib.instance.isGitRepository(path);
    }
    final gitDir = Directory('$path/.git');
    return await gitDir.exists();
  }

  /// Get the current branch name
  static Future<String?> getCurrentBranch(String repoPath) async {
    // No native impl for this, use Dart
    return _getCurrentBranchDart(repoPath);
  }

  /// Get monthly commit counts for a date range (defaults to current calendar year)
  /// If [authorOnly] is true, resolves the repo's git user.email and filters by it.
  static Future<Map<String, int>> getMonthlyCommitCounts(
    String repoPath, {
    DateTime? from,
    DateTime? to,
    bool authorOnly = false,
  }) async {
    String? author;
    if (authorOnly) {
      author = await getUserEmail(repoPath);
    }
    // Always use Dart fallback when we need author filtering
    if (author != null || from != null || to != null) {
      return _getMonthlyCommitCountsDart(repoPath, from: from, to: to, author: author);
    }
    if (_canUseNative) {
      return NativeLib.instance.getMonthlyCommitCounts(repoPath);
    }
    return _getMonthlyCommitCountsDart(repoPath);
  }

  /// Get total commits in a date range (defaults to current calendar year)
  /// If [authorOnly] is true, resolves the repo's git user.email and filters by it.
  static Future<int> getYearlyCommitCount(
    String repoPath, {
    DateTime? from,
    DateTime? to,
    bool authorOnly = false,
  }) async {
    String? author;
    if (authorOnly) {
      author = await getUserEmail(repoPath);
    }
    final since = from ?? DateTime(DateTime.now().year, 1, 1);
    return getCommitCount(repoPath, since: since, until: to, author: author);
  }



  /// Get the remote URL (origin) for a repository
  static Future<String?> getRemoteUrl(String repoPath) async {
    try {
      final result = await Process.run(
        'git',
        ['remote', 'get-url', 'origin'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        final url = result.stdout.toString().trim();
        return url.isNotEmpty ? url : null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the git user email configured for a repo (or global)
  static Future<String?> getUserEmail(String repoPath) async {
    try {
      final result = await Process.run(
        'git',
        ['config', 'user.email'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        final email = result.stdout.toString().trim();
        return email.isNotEmpty ? email : null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the effective "last changed" timestamp for a project.
  ///
  /// For git repos with uncommitted changes: checks the actual mtime of dirty
  /// files from `git status`, and returns whichever is newer — dirty files or
  /// last commit.
  /// For git repos without uncommitted changes: uses last commit date.
  /// For non-git projects: shallow file scan of top-level files + key subdirs.
  static Future<DateTime?> getLastChangedDate(String projectPath) async {
    final isGit = await isGitRepository(projectPath);
    final name = projectPath.split('/').last;

    if (isGit) {
      final lastCommit = await getLastCommitDate(projectPath);
      final hasChanges = await hasUncommittedChanges(projectPath);

      if (hasChanges) {
        // Get the actual mtime of files reported dirty by git status
        final dirtyMtime = await _dirtyFilesMtime(projectPath);

        // Return the most recent of: dirty file mtime, last commit
        final candidates = <DateTime>[
          if (dirtyMtime != null) dirtyMtime,
          if (lastCommit != null) lastCommit,
        ];
        if (candidates.isEmpty) return null;
        candidates.sort((a, b) => b.compareTo(a));
        return candidates.first;
      }

      return lastCommit;
    }

    // Non-git: shallow file scan
    AppLogger.debug(_tag, '$name: not a git repo, using file scan');
    return _shallowLastModified(projectPath);
  }

  /// Get the most recent mtime among files reported dirty by `git status`.
  static Future<DateTime?> _dirtyFilesMtime(String projectPath) async {
    try {
      final result = await Process.run(
        'git', ['status', '--porcelain'],
        workingDirectory: projectPath,
      );
      if (result.exitCode != 0) return null;

      final lines = result.stdout.toString().trim().split('\n');
      DateTime? newest;

      for (final line in lines) {
        if (line.length < 4) continue;
        // Format: "XY filename" or "XY filename -> renamed"
        final filePath = line.substring(3).split(' -> ').first;
        final file = File('$projectPath/$filePath');
        try {
          if (await file.exists()) {
            final stat = await file.stat();
            if (newest == null || stat.modified.isAfter(newest)) {
              newest = stat.modified;
            }
          }
        } catch (_) {}
      }

      return newest;
    } catch (_) {
      return null;
    }
  }

  /// Shallow scan: check mtimes of top-level files and first-level files in
  /// key source directories. Skips heavy/generated dirs.
  static Future<DateTime?> _shallowLastModified(String projectPath) async {
    const skipDirs = {
      '.git', 'node_modules', '.dart_tool', 'build', 'dist',
      '.gradle', 'Pods', 'vendor', '__pycache__', '.next',
      '.nuxt', 'target', '.build', 'DerivedData',
    };
    const sourceDirs = {
      'lib', 'src', 'app', 'pages', 'components', 'pkg', 'cmd',
      'internal', 'test', 'tests', 'spec',
    };

    DateTime? newest;

    void checkTime(DateTime mtime) {
      if (newest == null || mtime.isAfter(newest!)) {
        newest = mtime;
      }
    }

    final dir = Directory(projectPath);
    if (!await dir.exists()) return null;

    // Scan top-level entries
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
      if (name.startsWith('.') && name != '.env') continue;
      if (skipDirs.contains(name)) continue;

      final stat = await entity.stat();

      if (entity is File) {
        checkTime(stat.modified);
      } else if (entity is Directory && sourceDirs.contains(name)) {
        // One level deep into source directories
        try {
          await for (final sub in entity.list()) {
            if (sub is File) {
              final subStat = await sub.stat();
              checkTime(subStat.modified);
            }
          }
        } catch (_) {}
      }
    }

    return newest;
  }

  // ===========================================================================
  // Dart fallback implementations (using shell commands)
  // ===========================================================================

  static Future<DateTime?> _getLastCommitDateDart(String repoPath) async {
    try {
      final result = await Process.run(
        'git',
        ['log', '-1', '--format=%ct'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final timestamp = int.tryParse(result.stdout.toString().trim());
        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<int> _getCommitCountDart(String repoPath, {DateTime? since, DateTime? until, String? author}) async {
    try {
      final args = ['rev-list', '--count', 'HEAD'];
      if (since != null) {
        args.addAll(['--since', since.toIso8601String()]);
      }
      if (until != null) {
        args.addAll(['--until', until.toIso8601String()]);
      }
      if (author != null) {
        args.addAll(['--author', author]);
      }
      final result = await Process.run(
        'git',
        args,
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.toString().trim()) ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<bool> _hasUncommittedChangesDart(String repoPath) async {
    try {
      final result = await Process.run(
        'git',
        ['status', '--porcelain'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        return result.stdout.toString().trim().isNotEmpty;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<int> _getUnpushedCommitCountDart(String repoPath) async {
    try {
      final trackingResult = await Process.run(
        'git',
        ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}'],
        workingDirectory: repoPath,
      );
      if (trackingResult.exitCode != 0) {
        return 0;
      }

      final result = await Process.run(
        'git',
        ['rev-list', '--count', '@{upstream}..HEAD'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.toString().trim()) ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<String?> _getCurrentBranchDart(String repoPath) async {
    try {
      final result = await Process.run(
        'git',
        ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: repoPath,
      );
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, int>> _getMonthlyCommitCountsDart(
    String repoPath, {
    DateTime? from,
    DateTime? to,
    String? author,
  }) async {
    final counts = <String, int>{};
    final rangeStart = from ?? DateTime(DateTime.now().year, 1, 1);
    final rangeEnd = to ?? DateTime.now();

    // Iterate through each month in the range
    var cursor = DateTime(rangeStart.year, rangeStart.month, 1);
    final endBound = DateTime(rangeEnd.year, rangeEnd.month + 1, 1);

    while (cursor.isBefore(endBound)) {
      final monthStart = cursor;
      final monthEnd = DateTime(cursor.year, cursor.month + 1, 1);
      final monthKey = '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}';

      try {
        final args = [
          'rev-list',
          '--count',
          'HEAD',
          '--since=${monthStart.toIso8601String()}',
          '--until=${monthEnd.toIso8601String()}',
        ];
        if (author != null) {
          args.addAll(['--author', author]);
        }
        final result = await Process.run(
          'git',
          args,
          workingDirectory: repoPath,
        );

        if (result.exitCode == 0) {
          counts[monthKey] = int.tryParse(result.stdout.toString().trim()) ?? 0;
        } else {
          counts[monthKey] = 0;
        }
      } catch (e) {
        counts[monthKey] = 0;
      }

      cursor = monthEnd;
    }

    return counts;
  }
}
