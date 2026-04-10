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

    // Try the app bundle Frameworks path first (works in both release and debug
    // when the dylib has been copied to macos/Frameworks/).
    // Falls back to the relative dev path only if the bundle path fails.
    final executablePath = Platform.resolvedExecutable;
    final appDir = executablePath.substring(
        0, executablePath.lastIndexOf(Platform.pathSeparator));
    final bundlePath = '$appDir/../Frameworks/$libName';

    final pathsToTry = [
      bundlePath,
      // Dev fallback: relative path from project root (only works in debug
      // mode without hardened runtime)
      'rust/target/release/$libName',
    ];

    for (final path in pathsToTry) {
      try {
        _lib = DynamicLibrary.open(path);
        AppLogger.info('FFI', 'Loaded from: $path');
        return _lib!;
      } catch (_) {
        // Try next path
      }
    }

    final msg = 'Failed to load $libName from any of: $pathsToTry';
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
    AppLogger.debug('FFI', 'getLastCommitTimestamp(repoPath: $repoPath)');
    final pathPtr = repoPath.toNativeUtf8();
    try {
      final result = _gitLastCommitTimestamp(pathPtr);
      AppLogger.debug('FFI', 'getLastCommitTimestamp result: $result');
      return result;
    } catch (e) {
      AppLogger.error('FFI', 'getLastCommitTimestamp failed: $e');
      rethrow;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Get last commit as DateTime
  DateTime? getLastCommitDate(String repoPath) {
    AppLogger.debug('FFI', 'getLastCommitDate(repoPath: $repoPath)');
    try {
      final timestamp = getLastCommitTimestamp(repoPath);
      if (timestamp == 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    } catch (e) {
      AppLogger.error('FFI', 'getLastCommitDate failed: $e');
      return null;
    }
  }

  /// Get commit count (optionally since a date)
  int getCommitCount(String repoPath, {DateTime? since}) {
    AppLogger.debug('FFI', 'getCommitCount(repoPath: $repoPath, since: $since)');
    final pathPtr = repoPath.toNativeUtf8();
    final sinceTimestamp = since?.millisecondsSinceEpoch ?? 0;
    try {
      final result = _gitCommitCount(pathPtr, sinceTimestamp ~/ 1000);
      AppLogger.debug('FFI', 'getCommitCount result: $result');
      return result;
    } catch (e) {
      AppLogger.error('FFI', 'getCommitCount failed: $e');
      rethrow;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Check for uncommitted changes
  bool hasUncommittedChanges(String repoPath) {
    AppLogger.debug('FFI', 'hasUncommittedChanges(repoPath: $repoPath)');
    final pathPtr = repoPath.toNativeUtf8();
    try {
      final result = _gitHasUncommittedChanges(pathPtr) == 1;
      AppLogger.debug('FFI', 'hasUncommittedChanges result: $result');
      return result;
    } catch (e) {
      AppLogger.error('FFI', 'hasUncommittedChanges failed: $e');
      rethrow;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Get unpushed commit count
  int getUnpushedCommitCount(String repoPath) {
    AppLogger.debug('FFI', 'getUnpushedCommitCount(repoPath: $repoPath)');
    final pathPtr = repoPath.toNativeUtf8();
    try {
      final result = _gitUnpushedCommitCount(pathPtr);
      AppLogger.debug('FFI', 'getUnpushedCommitCount result: $result');
      return result;
    } catch (e) {
      AppLogger.error('FFI', 'getUnpushedCommitCount failed: $e');
      rethrow;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Check if path is a git repository
  bool isGitRepository(String path) {
    AppLogger.debug('FFI', 'isGitRepository(path: $path)');
    final pathPtr = path.toNativeUtf8();
    try {
      final result = _gitIsRepository(pathPtr) == 1;
      AppLogger.debug('FFI', 'isGitRepository result: $result');
      return result;
    } catch (e) {
      AppLogger.error('FFI', 'isGitRepository failed: $e');
      rethrow;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Get monthly commit counts
  Map<String, int> getMonthlyCommitCounts(String repoPath) {
    AppLogger.debug('FFI', 'getMonthlyCommitCounts(repoPath: $repoPath)');
    final pathPtr = repoPath.toNativeUtf8();
    try {
      final json = _callWithStringResult(() => _gitMonthlyCommitsJson(pathPtr));
      final map = jsonDecode(json) as Map<String, dynamic>;
      final result = map.map((k, v) => MapEntry(k, v as int));
      AppLogger.debug('FFI', 'getMonthlyCommitCounts result: $result');
      return result;
    } catch (e) {
      AppLogger.error('FFI', 'getMonthlyCommitCounts failed: $e');
      rethrow;
    } finally {
      malloc.free(pathPtr);
    }
  }

  // ==========================================================================
  // Public API - Health
  // ==========================================================================

  /// Calculate health score for a project
  Map<String, dynamic> calculateHealthScore(String projectPath) {
    AppLogger.debug('FFI', 'calculateHealthScore(projectPath: $projectPath)');
    final pathPtr = projectPath.toNativeUtf8();
    try {
      final json = _callWithStringResult(() => _calculateHealthScoreJson(pathPtr));
      final result = jsonDecode(json) as Map<String, dynamic>;
      AppLogger.debug('FFI', 'calculateHealthScore result: $result');
      return result;
    } catch (e) {
      AppLogger.error('FFI', 'calculateHealthScore failed: $e');
      rethrow;
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Calculate health scores for multiple projects
  List<Map<String, dynamic>> calculateHealthScoresBatch(List<String> paths) {
    AppLogger.debug('FFI', 'calculateHealthScoresBatch(paths: $paths)');
    final jsonInput = jsonEncode(paths);
    final inputPtr = jsonInput.toNativeUtf8();
    try {
      final json = _callWithStringResult(() => _calculateHealthScoresBatchJson(inputPtr));
      final list = jsonDecode(json) as List<dynamic>;
      final result = list.map((e) => e as Map<String, dynamic>).toList();
      AppLogger.debug('FFI', 'calculateHealthScoresBatch result: $result');
      return result;
    } catch (e) {
      AppLogger.error('FFI', 'calculateHealthScoresBatch failed: $e');
      rethrow;
    } finally {
      malloc.free(inputPtr);
    }
  }

  // ==========================================================================
  // Public API - Stats
  // ==========================================================================

  /// Calculate year-in-review stats for multiple projects
  Map<String, dynamic> calculateYearStats(List<String> projectPaths) {
    AppLogger.debug('FFI', 'calculateYearStats(projectPaths: $projectPaths)');
    final jsonInput = jsonEncode(projectPaths);
    final inputPtr = jsonInput.toNativeUtf8();
    try {
      final json = _callWithStringResult(() => _calculateYearStatsJson(inputPtr));
      final result = jsonDecode(json) as Map<String, dynamic>;
      AppLogger.debug('FFI', 'calculateYearStats result: $result');
      return result;
    } catch (e) {
      AppLogger.error('FFI', 'calculateYearStats failed: $e');
      rethrow;
    } finally {
      malloc.free(inputPtr);
    }
  }

  // ==========================================================================
  // Public API - File System
  // ==========================================================================

  /// Scan for git repositories
  List<String> scanForRepos(String rootPath, {int maxDepth = 2}) {
    AppLogger.debug('FFI', 'scanForRepos(rootPath: $rootPath, maxDepth: $maxDepth)');
    final pathPtr = rootPath.toNativeUtf8();
    try {
      final json = _callWithStringResult(() => _scanForReposJson(pathPtr, maxDepth));
      final list = jsonDecode(json) as List<dynamic>;
      final result = list.cast<String>();
      AppLogger.debug('FFI', 'scanForRepos result: $result');
      return result;
    } catch (e) {
      AppLogger.error('FFI', 'scanForRepos failed: $e');
      rethrow;
    } finally {
      malloc.free(pathPtr);
    }
  }
}
