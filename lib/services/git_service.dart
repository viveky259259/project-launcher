import 'dart:io';

class GitService {
  /// Get the date of the last commit in a repository
  static Future<DateTime?> getLastCommitDate(String repoPath) async {
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

  /// Get the number of commits in a repository, optionally since a specific date
  static Future<int> getCommitCount(String repoPath, {DateTime? since}) async {
    try {
      final args = ['rev-list', '--count', 'HEAD'];
      if (since != null) {
        args.addAll(['--since', since.toIso8601String()]);
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

  /// Check if there are uncommitted changes (modified, staged, or untracked files)
  static Future<bool> hasUncommittedChanges(String repoPath) async {
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

  /// Get the number of commits that haven't been pushed to the remote
  static Future<int> getUnpushedCommitCount(String repoPath) async {
    try {
      // First check if there's a remote tracking branch
      final trackingResult = await Process.run(
        'git',
        ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}'],
        workingDirectory: repoPath,
      );
      if (trackingResult.exitCode != 0) {
        // No tracking branch set up
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

  /// Check if a directory is a git repository
  static Future<bool> isGitRepository(String path) async {
    final gitDir = Directory('$path/.git');
    return await gitDir.exists();
  }

  /// Get the current branch name
  static Future<String?> getCurrentBranch(String repoPath) async {
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

  /// Get monthly commit counts for the past year (for year-in-review)
  static Future<Map<String, int>> getMonthlyCommitCounts(String repoPath) async {
    final counts = <String, int>{};
    final now = DateTime.now();

    for (var i = 11; i >= 0; i--) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);

      try {
        final result = await Process.run(
          'git',
          [
            'rev-list',
            '--count',
            'HEAD',
            '--since=${monthStart.toIso8601String()}',
            '--until=${monthEnd.toIso8601String()}',
          ],
          workingDirectory: repoPath,
        );

        final monthKey = '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}';
        if (result.exitCode == 0) {
          counts[monthKey] = int.tryParse(result.stdout.toString().trim()) ?? 0;
        } else {
          counts[monthKey] = 0;
        }
      } catch (e) {
        final monthKey = '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}';
        counts[monthKey] = 0;
      }
    }

    return counts;
  }

  /// Get total commits in the past year
  static Future<int> getYearlyCommitCount(String repoPath) async {
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    return getCommitCount(repoPath, since: oneYearAgo);
  }
}
