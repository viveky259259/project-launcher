import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'app_logger.dart';

/// FFI bindings to the Rust native library for heavy operations
class NativeLib {
  static NativeLib? _instance;
  static DynamicLibrary? _lib;

  NativeLib._();

  /// Get singleton instance
  static NativeLib get instance {
    _instance ??= NativeLib._();
    return _instance!;
  }

  static bool? _available;

  /// Check if native library is available
  static bool get isAvailable {
    if (_available != null) return _available!;
    try {
      _loadLibrary();
      _available = true;
      AppLogger.info('FFI', 'Native library loaded successfully');
      return true;
    } catch (e) {
      _available = false;
      AppLogger.error('FFI', 'Native library not available: $e');
      return false;
    }
  }

  static DynamicLibrary _loadLibrary() {
    if (_lib != null) return _lib!;

    final libName = Platform.isMacOS
        ? 'libproject_launcher_core.dylib'
        : Platform.isLinux
            ? 'libproject_launcher_core.so'
            : 'project_launcher_core.dll';

    // Try multiple paths
    final executablePath = Platform.resolvedExecutable;
    final sep = Platform.pathSeparator;
    final appDir = executablePath.substring(0, executablePath.lastIndexOf(sep));

    final paths = <String>[];
    if (Platform.isMacOS) {
      paths.addAll([
        '$appDir/../Frameworks/$libName',
        'macos/Frameworks/$libName',
      ]);
    } else if (Platform.isWindows) {
      paths.add('$appDir\\$libName');
    } else {
      // Linux
      paths.addAll([
        '$appDir/lib/$libName',
        '$appDir/../lib/$libName',
      ]);
    }
    // Development fallback
    paths.add('rust${sep}target${sep}release$sep$libName');

    final errors = <String>[];
    for (final path in paths) {
      try {
        _lib = DynamicLibrary.open(path);
        AppLogger.info('FFI', 'Loaded from: $path');
        return _lib!;
      } catch (e) {
        errors.add('  $path: $e');
        continue;
      }
    }

    final msg = 'Failed to load $libName. Tried:\n${errors.join('\n')}';
    AppLogger.error('FFI', msg);
    throw Exception(msg);
  }

  // ==========================================================================
  // FFI Function Types
  // ==========================================================================

  // Free string
  late final _freeString = _loadLibrary().lookupFunction<
      Void Function(Pointer<Utf8>),
      void Function(Pointer<Utf8>)>('free_string');

  // Git functions
  late final _gitLastCommitTimestamp = _loadLibrary().lookupFunction<
      Int64 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)>('git_last_commit_timestamp');

  late final _gitCommitCount = _loadLibrary().lookupFunction<
      Int32 Function(Pointer<Utf8>, Int64),
      int Function(Pointer<Utf8>, int)>('git_commit_count');

  late final _gitHasUncommittedChanges = _loadLibrary().lookupFunction<
      Int32 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)>('git_has_uncommitted_changes');

  late final _gitUnpushedCommitCount = _loadLibrary().lookupFunction<
      Int32 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)>('git_unpushed_commit_count');

  late final _gitIsRepository = _loadLibrary().lookupFunction<
      Int32 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)>('git_is_repository');

  late final _gitMonthlyCommitsJson = _loadLibrary().lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('git_monthly_commits_json');

  // Health functions
  late final _calculateHealthScoreJson = _loadLibrary().lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('calculate_health_score_json');

  late final _calculateHealthScoresBatchJson = _loadLibrary().lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('calculate_health_scores_batch_json');

  // Stats functions
  late final _calculateYearStatsJson = _loadLibrary().lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>),
      Pointer<Utf8> Function(Pointer<Utf8>)>('calculate_year_stats_json');

  // File system functions
  late final _scanForReposJson = _loadLibrary().lookupFunction<
      Pointer<Utf8> Function(Pointer<Utf8>, Int32),
      Pointer<Utf8> Function(Pointer<Utf8>, int)>('scan_for_repos_json');

  // ==========================================================================
  // Helper methods
  // ==========================================================================

  String _callWithStringResult(Pointer<Utf8> Function() fn) {
    final ptr = fn();
    final result = ptr.toDartString();
    _freeString(ptr);
    return result;
  }

  // ==========================================================================
  // Public API - Git
  // ==========================================================================

  /// Get last commit timestamp (Unix seconds)
  int getLastCommitTimestamp(String repoPath) {
    final pathPtr = repoPath.toNativeUtf8();
    try {
      return _gitLastCommitTimestamp(pathPtr);
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Get last commit as DateTime
  DateTime? getLastCommitDate(String repoPath) {
    final timestamp = getLastCommitTimestamp(repoPath);
    if (timestamp == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  /// Get commit count (optionally since a date)
  int getCommitCount(String repoPath, {DateTime? since}) {
    final pathPtr = repoPath.toNativeUtf8();
    final sinceTimestamp = since?.millisecondsSinceEpoch ?? 0;
    try {
      return _gitCommitCount(pathPtr, sinceTimestamp ~/ 1000);
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Check for uncommitted changes
  bool hasUncommittedChanges(String repoPath) {
    final pathPtr = repoPath.toNativeUtf8();
    try {
      return _gitHasUncommittedChanges(pathPtr) == 1;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Get unpushed commit count
  int getUnpushedCommitCount(String repoPath) {
    final pathPtr = repoPath.toNativeUtf8();
    try {
      return _gitUnpushedCommitCount(pathPtr);
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Check if path is a git repository
  bool isGitRepository(String path) {
    final pathPtr = path.toNativeUtf8();
    try {
      return _gitIsRepository(pathPtr) == 1;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Get monthly commit counts
  Map<String, int> getMonthlyCommitCounts(String repoPath) {
    final pathPtr = repoPath.toNativeUtf8();
    try {
      final json = _callWithStringResult(() => _gitMonthlyCommitsJson(pathPtr));
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as int));
    } finally {
      malloc.free(pathPtr);
    }
  }

  // ==========================================================================
  // Public API - Health
  // ==========================================================================

  /// Calculate health score for a project
  Map<String, dynamic> calculateHealthScore(String projectPath) {
    final pathPtr = projectPath.toNativeUtf8();
    try {
      final json = _callWithStringResult(() => _calculateHealthScoreJson(pathPtr));
      return jsonDecode(json) as Map<String, dynamic>;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Calculate health scores for multiple projects
  List<Map<String, dynamic>> calculateHealthScoresBatch(List<String> paths) {
    final jsonInput = jsonEncode(paths);
    final inputPtr = jsonInput.toNativeUtf8();
    try {
      final json = _callWithStringResult(() => _calculateHealthScoresBatchJson(inputPtr));
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } finally {
      malloc.free(inputPtr);
    }
  }

  // ==========================================================================
  // Public API - Stats
  // ==========================================================================

  /// Calculate year-in-review stats for multiple projects
  Map<String, dynamic> calculateYearStats(List<String> projectPaths) {
    final jsonInput = jsonEncode(projectPaths);
    final inputPtr = jsonInput.toNativeUtf8();
    try {
      final json = _callWithStringResult(() => _calculateYearStatsJson(inputPtr));
      return jsonDecode(json) as Map<String, dynamic>;
    } finally {
      malloc.free(inputPtr);
    }
  }

  // ==========================================================================
  // Public API - File System
  // ==========================================================================

  /// Scan for git repositories
  List<String> scanForRepos(String rootPath, {int maxDepth = 2}) {
    final pathPtr = rootPath.toNativeUtf8();
    try {
      final json = _callWithStringResult(() => _scanForReposJson(pathPtr, maxDepth));
      final list = jsonDecode(json) as List<dynamic>;
      return list.cast<String>();
    } finally {
      malloc.free(pathPtr);
    }
  }
}
