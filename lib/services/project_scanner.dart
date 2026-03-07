import 'dart:io';
import '../models/project.dart';
import 'project_storage.dart';

class ProjectScanner {
  static const List<String> defaultScanPaths = [
    'Projects',
    'Developer',
    'Development',
    'Code',
    'repos',
    'git',
    'GitHub',
    'workspace',
    'Work',
    'Sites',
    'Documents/Projects',
    'Documents/Code',
    'Documents/GitHub',
  ];

  /// Get the full paths to scan based on home directory
  static List<String> getScanPaths() {
    final home = Platform.environment['HOME'] ?? '';
    return defaultScanPaths.map((p) => '$home/$p').toList();
  }

  /// Scan a directory for git repositories (max 2 levels deep)
  static Future<List<String>> scanDirectory(String path, {int maxDepth = 2}) async {
    final results = <String>[];
    final dir = Directory(path);

    if (!await dir.exists()) {
      return results;
    }

    await _scanRecursive(dir, results, 0, maxDepth);
    return results;
  }

  static Future<void> _scanRecursive(
    Directory dir,
    List<String> results,
    int currentDepth,
    int maxDepth,
  ) async {
    if (currentDepth > maxDepth) return;

    try {
      // Check if this directory is a git repo
      final gitDir = Directory('${dir.path}/.git');
      if (await gitDir.exists()) {
        results.add(dir.path);
        return; // Don't scan inside git repos
      }

      // Scan subdirectories
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          final name = entity.path.split('/').last;
          // Skip hidden directories and common non-project directories
          if (name.startsWith('.') ||
              name == 'node_modules' ||
              name == 'build' ||
              name == 'dist' ||
              name == '.dart_tool' ||
              name == 'Pods' ||
              name == 'vendor' ||
              name == '__pycache__') {
            continue;
          }
          await _scanRecursive(entity, results, currentDepth + 1, maxDepth);
        }
      }
    } catch (e) {
      // Permission denied or other errors - skip this directory
      // Permission denied or symlink error — skip silently
    }
  }

  /// Scan all default paths and return found git repositories
  static Future<List<String>> scanAllDefaultPaths({
    void Function(String currentPath)? onProgress,
    void Function(int found)? onFound,
  }) async {
    final allResults = <String>{};
    final paths = getScanPaths();

    for (final path in paths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        onProgress?.call(path);
        final results = await scanDirectory(path);
        allResults.addAll(results);
        onFound?.call(allResults.length);
      }
    }

    return allResults.toList()..sort();
  }

  /// Scan and add new projects (skips already added ones)
  static Future<ScanResult> scanAndAddProjects({
    void Function(String currentPath)? onProgress,
    void Function(int found)? onFound,
  }) async {
    final existingProjects = await ProjectStorage.loadProjects();
    final existingPaths = existingProjects.map((p) => p.path).toSet();

    final foundPaths = await scanAllDefaultPaths(
      onProgress: onProgress,
      onFound: onFound,
    );

    final newPaths = foundPaths.where((p) => !existingPaths.contains(p)).toList();
    int added = 0;

    for (final path in newPaths) {
      final name = path.split('/').last;
      final project = Project(
        name: name,
        path: path,
        addedAt: DateTime.now(),
      );
      await ProjectStorage.addProject(project);
      added++;
    }

    return ScanResult(
      totalFound: foundPaths.length,
      newlyAdded: added,
      alreadyExists: foundPaths.length - added,
    );
  }

  /// Scan a custom path
  static Future<ScanResult> scanCustomPath(String path) async {
    final existingProjects = await ProjectStorage.loadProjects();
    final existingPaths = existingProjects.map((p) => p.path).toSet();

    final foundPaths = await scanDirectory(path, maxDepth: 3);
    final newPaths = foundPaths.where((p) => !existingPaths.contains(p)).toList();
    int added = 0;

    for (final foundPath in newPaths) {
      final name = foundPath.split('/').last;
      final project = Project(
        name: name,
        path: foundPath,
        addedAt: DateTime.now(),
      );
      await ProjectStorage.addProject(project);
      added++;
    }

    return ScanResult(
      totalFound: foundPaths.length,
      newlyAdded: added,
      alreadyExists: foundPaths.length - added,
    );
  }
}

class ScanResult {
  final int totalFound;
  final int newlyAdded;
  final int alreadyExists;

  ScanResult({
    required this.totalFound,
    required this.newlyAdded,
    required this.alreadyExists,
  });
}
